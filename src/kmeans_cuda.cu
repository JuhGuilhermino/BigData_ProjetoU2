#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <random>
#include <set>
#include <string>
#include <vector>

#define CUDA_CHECK(call)                                                           \
    do {                                                                           \
        cudaError_t err = (call);                                                  \
        if (err != cudaSuccess) {                                                  \
            std::cerr << "Erro CUDA: " << cudaGetErrorString(err) << " ("          \
                      << __FILE__ << ":" << __LINE__ << ")" << std::endl;          \
            std::exit(1);                                                          \
        }                                                                          \
    } while (0)

struct Centroid{
    double x;
    double y;
    double t;
};

struct Scale {
    double min;
    double span;
};

const std::string FILE_NAME = "src/data/twitter_processed.csv";
const int MAX_K = 800;

bool readData(const std::string& path, std::vector<double>& xs, std::vector<double>& ys,
              std::vector<double>& ts) {
    std::ifstream file(path);
    std::string line;

    if (!file.is_open()) {
        std::cerr << "Erro ao abrir o arquivo: " << path << std::endl;
        return false;
    }

    // Igonra cabeçaçho
    std::getline(file, line);

    // Lê arquivo linha por linha
    while (std::getline(file, line)) {
        if (line.empty()) continue;

        char* next;
        xs.push_back(std::strtod(line.c_str(), &next));
        ys.push_back(std::strtod(next + 1, &next));
        ts.push_back(std::strtod(next + 1, &next));
    }

    return true;
}

Scale normalize(std::vector<double>& values) {
    auto [lo, hi] = std::minmax_element(values.begin(), values.end());
    Scale scale{*lo, *hi > *lo ? *hi - *lo : 1.0};
    for (double& v : values)
        v = (v - scale.min) / scale.span;
    return scale;
}

std::vector<Centroid> initCentroids(const std::vector<double>& xs, const std::vector<double>& ys,
                                    const std::vector<double>& ts, int k, unsigned seed) {
    std::mt19937_64 rng(seed);
    std::set<long long> chosen;
    while (static_cast<int>(chosen.size()) < k)
        chosen.insert(static_cast<long long>(rng() % xs.size()));

    std::vector<Centroid> centroids;
    for (long long g : chosen)
        centroids.push_back({xs[g], ys[g], ts[g]});
    return centroids;
}

__global__ void assignKernel(const double* __restrict__ x, const double* __restrict__ y,
                             const double* __restrict__ t, int* label, long long n, int k,
                             const double* cx, const double* cy, const double* ct,
                             double* sums, unsigned long long* counts, int* changed) {
    extern __shared__ double shared[];
    double* scx = shared;
    double* scy = scx + k;
    double* sct = scy + k;
    double* ssx = sct + k;
    double* ssy = ssx + k;
    double* sst = ssy + k;
    unsigned long long* scount = reinterpret_cast<unsigned long long*>(sst + k);

    for (int c = threadIdx.x; c < k; c += blockDim.x) {
        scx[c] = cx[c];
        scy[c] = cy[c];
        sct[c] = ct[c];
        ssx[c] = 0.0;
        ssy[c] = 0.0;
        sst[c] = 0.0;
        scount[c] = 0;
    }
    __syncthreads();

    long long stride = static_cast<long long>(gridDim.x) * blockDim.x;
    for (long long i = static_cast<long long>(blockIdx.x) * blockDim.x + threadIdx.x; i < n; i += stride) {
        double px = x[i];
        double py = y[i];
        double pt = t[i];

        int best = 0;
        double bestDistance = (px - scx[0]) * (px - scx[0]) + (py - scy[0]) * (py - scy[0])
                            + (pt - sct[0]) * (pt - sct[0]);
        for (int c = 1; c < k; ++c) {
            double d = (px - scx[c]) * (px - scx[c]) + (py - scy[c]) * (py - scy[c])
                     + (pt - sct[c]) * (pt - sct[c]);
            if (d < bestDistance) {
                bestDistance = d;
                best = c;
            }
        }

        if (label[i] != best) {
            label[i] = best;
            *changed = 1;
        }

        atomicAdd(&ssx[best], px);
        atomicAdd(&ssy[best], py);
        atomicAdd(&sst[best], pt);
        atomicAdd(&scount[best], 1ULL);
    }
    __syncthreads();

    for (int c = threadIdx.x; c < k; c += blockDim.x) {
        atomicAdd(&sums[3 * c], ssx[c]);
        atomicAdd(&sums[3 * c + 1], ssy[c]);
        atomicAdd(&sums[3 * c + 2], sst[c]);
        atomicAdd(&counts[c], scount[c]);
    }
}

int main(int argc, char *argv[]) {
    std::string path = argc > 1 ? argv[1] : FILE_NAME;
    int k = argc > 2 ? std::stoi(argv[2]) : 8;
    int maxIterations = argc > 3 ? std::stoi(argv[3]) : 100;
    unsigned seed = argc > 4 ? static_cast<unsigned>(std::stoul(argv[4])) : 42;

    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::cout << "GPU: " << prop.name << " | " << prop.totalGlobalMem / (1024 * 1024) << " MB" << std::endl;

    auto readStart = std::chrono::steady_clock::now();
    std::vector<double> xs, ys, ts;
    if (!readData(path, xs, ys, ts)) return 1;

    long long n = static_cast<long long>(xs.size());
    if (n == 0 || k < 1 || k > MAX_K || k > n) {
        std::cerr << "Sem dados ou k invalido (k=" << k << ", maximo " << MAX_K
                  << ", tweets=" << n << ")" << std::endl;
        return 1;
    }

    Scale scale[3] = {normalize(xs), normalize(ys), normalize(ts)};
    std::chrono::duration<double> readTime = std::chrono::steady_clock::now() - readStart;
    std::cout << "Tweets: " << n << " | k: " << k << std::endl;

    std::vector<Centroid> centroids = initCentroids(xs, ys, ts, k, seed);

    auto copyStart = std::chrono::steady_clock::now();
    double *d_x, *d_y, *d_t, *d_cx, *d_cy, *d_ct, *d_sums;
    int *d_label, *d_changed;
    unsigned long long* d_counts;
    CUDA_CHECK(cudaMalloc(&d_x, n * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_y, n * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_t, n * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_label, n * sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_cx, k * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_cy, k * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_ct, k * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_sums, 3 * k * sizeof(double)));
    CUDA_CHECK(cudaMalloc(&d_counts, k * sizeof(unsigned long long)));
    CUDA_CHECK(cudaMalloc(&d_changed, sizeof(int)));
    CUDA_CHECK(cudaMemcpy(d_x, xs.data(), n * sizeof(double), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_y, ys.data(), n * sizeof(double), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_t, ts.data(), n * sizeof(double), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(d_label, 0xFF, n * sizeof(int)));
    std::chrono::duration<double> copyTime = std::chrono::steady_clock::now() - copyStart;

    const int threads = 256;
    const int blocks = static_cast<int>(std::min<long long>((n + threads - 1) / threads, 2048));
    const size_t sharedBytes = 6 * k * sizeof(double) + k * sizeof(unsigned long long);

    std::vector<double> cx(k), cy(k), ct(k), sums(3 * k);
    std::vector<unsigned long long> counts(k, 0);

    CUDA_CHECK(cudaDeviceSynchronize());
    auto kmeansStart = std::chrono::steady_clock::now();

    for (int iter = 0; iter < maxIterations; ++iter) {
        for (int c = 0; c < k; ++c) {
            cx[c] = centroids[c].x;
            cy[c] = centroids[c].y;
            ct[c] = centroids[c].t;
        }
        CUDA_CHECK(cudaMemcpy(d_cx, cx.data(), k * sizeof(double), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(d_cy, cy.data(), k * sizeof(double), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(d_ct, ct.data(), k * sizeof(double), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemset(d_sums, 0, 3 * k * sizeof(double)));
        CUDA_CHECK(cudaMemset(d_counts, 0, k * sizeof(unsigned long long)));
        CUDA_CHECK(cudaMemset(d_changed, 0, sizeof(int)));

        assignKernel<<<blocks, threads, sharedBytes>>>(d_x, d_y, d_t, d_label, n, k,
                                                      d_cx, d_cy, d_ct,
                                                      d_sums, d_counts, d_changed);
        CUDA_CHECK(cudaGetLastError());

        int changed;
        CUDA_CHECK(cudaMemcpy(&changed, d_changed, sizeof(int), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(sums.data(), d_sums, 3 * k * sizeof(double), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(counts.data(), d_counts, k * sizeof(unsigned long long), cudaMemcpyDeviceToHost));

        if (!changed && iter > 0) {
            std::cout << "Convergiu na iteracao " << iter + 1 << '\n';
            break;
        }

        for (int c = 0; c < k; ++c) {
            if (counts[c] > 0) {
                centroids[c].x = sums[3 * c] / counts[c];
                centroids[c].y = sums[3 * c + 1] / counts[c];
                centroids[c].t = sums[3 * c + 2] / counts[c];
            }
        }

        if (iter == maxIterations - 1)
            std::cout << "Limite de iteracoes atingido.\n";
    }

    std::chrono::duration<double> kmeansTime = std::chrono::steady_clock::now() - kmeansStart;

    std::cout << std::fixed << std::setprecision(1);
    for (int c = 0; c < k; ++c)
        std::cout << "Cluster " << c << ": " << counts[c] << " tweets | centroide: x="
                  << centroids[c].x * scale[0].span + scale[0].min << " m, y="
                  << centroids[c].y * scale[1].span + scale[1].min << " m, t="
                  << centroids[c].t * scale[2].span / 3600.0 << " h apos o inicio\n";
    std::cout << std::setprecision(3);
    std::cout << "Tempo de leitura: " << readTime.count() << " s\n";
    std::cout << "Tempo de copia para a GPU: " << copyTime.count() << " s\n";
    std::cout << "Tempo do k-means: " << kmeansTime.count() << " s\n";

    cudaFree(d_x);
    cudaFree(d_y);
    cudaFree(d_t);
    cudaFree(d_label);
    cudaFree(d_cx);
    cudaFree(d_cy);
    cudaFree(d_ct);
    cudaFree(d_sums);
    cudaFree(d_counts);
    cudaFree(d_changed);
    return 0;
}
