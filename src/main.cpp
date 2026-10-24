#include <mpi.h>

#include <algorithm>
#include <array>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <set>
#include <string>
#include <vector>

struct Tweet {
    double x;
    double y;
    double t;
    int cluster = -1;
};

struct Centroid{
    double x;
    double y;
    double t;
};

struct Range {
    std::array<double, 3> min;
    std::array<double, 3> max;
};

const std::string FILE_NAME = "src/data/twitter_processed.csv";

using Dataset = std::vector<Tweet>;

Dataset readData(const std::string& path, int rank, int size) {
    std::ifstream file(path, std::ios::binary);
    std::string line;
    Dataset dataset;

    if (!file.is_open()) {
        if (rank == 0)
            std::cerr << "Erro ao abrir o arquivo: " << path << std::endl;
        return dataset;
    }

    file.seekg(0, std::ios::end);
    long long fileSize = file.tellg();
    long long begin = fileSize * rank / size;
    long long end = fileSize * (rank + 1) / size;
    long long pos;

    if (begin == 0) {
        // Igonra cabeçaçho
        file.seekg(0);
        std::getline(file, line);
        pos = static_cast<long long>(line.size()) + 1;
    } else {
        file.seekg(begin - 1);
        std::getline(file, line);
        pos = begin - 1 + static_cast<long long>(line.size()) + 1;
    }

    // Lê arquivo linha por linha
    while (pos < end && std::getline(file, line)) {
        pos += static_cast<long long>(line.size()) + 1;
        if (line.empty()) continue;

        char* next;
        Tweet t;
        t.x = std::strtod(line.c_str(), &next);
        t.y = std::strtod(next + 1, &next);
        t.t = std::strtod(next + 1, &next);

        dataset.push_back(t);
    }

    return dataset;
}

double span(const Range& range, int d) {
    double s = range.max[d] - range.min[d];
    return s > 0.0 ? s : 1.0;
}

Range computeRange(const Dataset& data) {
    std::array<double, 3> lo, hi;
    lo.fill(std::numeric_limits<double>::max());
    hi.fill(std::numeric_limits<double>::lowest());

    for (const auto& t : data) {
        lo[0] = std::min(lo[0], t.x);
        lo[1] = std::min(lo[1], t.y);
        lo[2] = std::min(lo[2], t.t);
        hi[0] = std::max(hi[0], t.x);
        hi[1] = std::max(hi[1], t.y);
        hi[2] = std::max(hi[2], t.t);
    }

    Range range;
    MPI_Allreduce(lo.data(), range.min.data(), 3, MPI_DOUBLE, MPI_MIN, MPI_COMM_WORLD);
    MPI_Allreduce(hi.data(), range.max.data(), 3, MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
    return range;
}

void normalize(Dataset& data, const Range& range) {
    for (auto& t : data) {
        t.x = (t.x - range.min[0]) / span(range, 0);
        t.y = (t.y - range.min[1]) / span(range, 1);
        t.t = (t.t - range.min[2]) / span(range, 2);
    }
}

double distanceSquared(const Tweet& t, const Centroid& c){
    return (t.x - c.x) * (t.x - c.x) + (t.y - c.y) * (t.y - c.y) + (t.t - c.t) * (t.t - c.t);
}

std::vector<Centroid> initCentroids(const Dataset& data, int k, unsigned seed,
                                    long long offset, long long total) {
    std::mt19937_64 rng(seed);
    std::set<long long> chosen;
    while (static_cast<int>(chosen.size()) < k)
        chosen.insert(static_cast<long long>(rng() % total));

    std::vector<double> buf(3 * k, 0.0);
    int c = 0;
    for (long long g : chosen) {
        if (g >= offset && g < offset + static_cast<long long>(data.size())) {
            buf[3 * c] = data[g - offset].x;
            buf[3 * c + 1] = data[g - offset].y;
            buf[3 * c + 2] = data[g - offset].t;
        }
        ++c;
    }
    MPI_Allreduce(MPI_IN_PLACE, buf.data(), 3 * k, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    std::vector<Centroid> centroids(k);
    for (int i = 0; i < k; ++i)
        centroids[i] = {buf[3 * i], buf[3 * i + 1], buf[3 * i + 2]};
    return centroids;
}

std::vector<Centroid> kmeans(Dataset& data, int k, int maxIterations, unsigned seed,
                             long long offset, long long total, int rank){
    //inicializar centroides aleatoriamente
    std::vector<Centroid> centroids = initCentroids(data, k, seed, offset, total);

    for (int iter = 0; iter < maxIterations; ++iter) {
        int changed = 0;

        // Atribui cada tweet ao centroide mais proximo.
        for (auto& t : data) {
            int bestCluster = 0;
            double bestDistance = distanceSquared(t, centroids[0]);

            for (int c = 1; c < k; ++c) {
                double d = distanceSquared(t, centroids[c]);

                if (d < bestDistance) {
                    bestDistance = d;
                    bestCluster = c;
                }
            }

            if (t.cluster != bestCluster) {
                t.cluster = bestCluster;
                changed = 1;
            }
        }

        int anyChanged;
        MPI_Allreduce(&changed, &anyChanged, 1, MPI_INT, MPI_MAX, MPI_COMM_WORLD);

        if (!anyChanged && iter > 0) {
            if (rank == 0)
                std::cout << "Convergiu na iteracao "
                          << iter + 1 << '\n';
            break;
        }

        // Calcula novos centroides.
        std::vector<double> sums(3 * k, 0.0);
        std::vector<long long> counts(k, 0);

        for (const auto& t : data) {
            int c = t.cluster;
            sums[3 * c] += t.x;
            sums[3 * c + 1] += t.y;
            sums[3 * c + 2] += t.t;
            counts[c]++;
        }

        MPI_Allreduce(MPI_IN_PLACE, sums.data(), 3 * k, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
        MPI_Allreduce(MPI_IN_PLACE, counts.data(), k, MPI_LONG_LONG, MPI_SUM, MPI_COMM_WORLD);

        for (int c = 0; c < k; ++c) {
            if (counts[c] > 0) {
                centroids[c].x = sums[3 * c] / counts[c];
                centroids[c].y = sums[3 * c + 1] / counts[c];
                centroids[c].t = sums[3 * c + 2] / counts[c];
            }
        }

        if (iter == maxIterations - 1 && rank == 0)
            std::cout << "Limite de iteracoes atingido.\n";
    }

    return centroids;
}

int main(int argc, char *argv[]) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    std::string path = argc > 1 ? argv[1] : FILE_NAME;
    int k = argc > 2 ? std::stoi(argv[2]) : 8;
    int maxIterations = argc > 3 ? std::stoi(argv[3]) : 100;
    unsigned seed = argc > 4 ? static_cast<unsigned>(std::stoul(argv[4])) : 42;

    MPI_Barrier(MPI_COMM_WORLD);
    double readStart = MPI_Wtime();
    // Ler instâncias transformando os dados para a estrutura
    Dataset dataset = readData(path, rank, size);

    long long local = static_cast<long long>(dataset.size());
    long long offset = 0, total = 0;
    MPI_Exscan(&local, &offset, 1, MPI_LONG_LONG, MPI_SUM, MPI_COMM_WORLD);
    if (rank == 0) offset = 0;
    MPI_Allreduce(&local, &total, 1, MPI_LONG_LONG, MPI_SUM, MPI_COMM_WORLD);

    if (total == 0 || k < 1 || k > total) {
        if (rank == 0)
            std::cerr << "Sem dados ou k invalido (k=" << k << ", tweets=" << total << ")" << std::endl;
        MPI_Finalize();
        return 1;
    }

    Range range = computeRange(dataset);
    normalize(dataset, range);
    double readTime = MPI_Wtime() - readStart;

    if (rank == 0)
        std::cout << "Processos: " << size << " | tweets: " << total << " | k: " << k << std::endl;

    MPI_Barrier(MPI_COMM_WORLD);
    double kmeansStart = MPI_Wtime();
    std::vector<Centroid> centroids = kmeans(dataset, k, maxIterations, seed, offset, total, rank);
    double kmeansTime = MPI_Wtime() - kmeansStart;

    std::vector<long long> sizes(k, 0);
    for (const auto& t : dataset)
        sizes[t.cluster]++;
    MPI_Reduce(rank == 0 ? MPI_IN_PLACE : sizes.data(), sizes.data(), k, MPI_LONG_LONG,
               MPI_SUM, 0, MPI_COMM_WORLD);

    double maxRead, maxKmeans;
    MPI_Reduce(&readTime, &maxRead, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&kmeansTime, &maxKmeans, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        std::cout << std::fixed << std::setprecision(1);
        for (int c = 0; c < k; ++c)
            std::cout << "Cluster " << c << ": " << sizes[c] << " tweets | centroide: x="
                      << centroids[c].x * span(range, 0) + range.min[0] << " m, y="
                      << centroids[c].y * span(range, 1) + range.min[1] << " m, t="
                      << centroids[c].t * span(range, 2) / 3600.0 << " h apos o inicio\n";
        std::cout << std::setprecision(3);
        std::cout << "Tempo de leitura: " << maxRead << " s\n";
        std::cout << "Tempo do k-means: " << maxKmeans << " s\n";
    }

    MPI_Finalize();
    return 0;
}
