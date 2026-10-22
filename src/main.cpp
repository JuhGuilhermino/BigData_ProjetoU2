#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <numeric>
#include <random>
#include <stdexcept>

struct Tweet {
    double x;
    double y;
    long long timestamp;
    int timezone;
    int cluster = -1;
};

struct Centroid{
    double x;
    double y;
};

const std::string FILE_NAME = "src/data/twitter_processed.csv";

using Dataset = std::vector<Tweet>;

Dataset readData() {
    std::ifstream file(FILE_NAME);
    std::string line;
    Dataset dataset;

    if (!file.is_open()) {
        std::cerr << "Erro ao abrir o arquivo: " << FILE_NAME << std::endl;
    }

    // Igonra cabeçaçho
    std::getline(file, line); 

    // Lê arquivo linha por linha
    while (std::getline(file, line)) {
        if (line.empty()) continue;

        std::stringstream ss(line);
        std::string campo;
        Tweet t;
        
        std::getline(ss, campo, ',');
        t.x = std::stod(campo);

        std::getline(ss, campo, ',');
        t.y = std::stod(campo);

        std::getline(ss, campo, ',');
        t.timestamp = std::stod(campo);

        std::getline(ss, campo, ',');
        t.timezone = std::stod(campo);
    
        dataset.push_back(t);
    }

    file.close();

    std::cout << "Leitura concluída com sucesso! Total de registos carregados: " << dataset.size() << std::endl;

    return dataset;
}

double distanceSquared(const Tweet& t, const Centroid& c){
    return (t.x - c.x) * (t.x - c.x) + (t.y - c.y) * (t.y - c.y);
}

void kmeans2D(Dataset& data, int k, int maxIterations){
    int n = static_cast<int>(data.size());

    //inicializar centroides aleatoriamente
    std::vector<int> indices(n);
    for (int i = 0; i < n; ++i)
        indices[i] = i;

    std::mt19937 rng(std::random_device{}());
    std::shuffle(indices.begin(), indices.end(), rng);

    std::vector<Centroid> centroids(k);
    for (int c = 0; c < k; ++c) {
        centroids[c] = {
            data[indices[c]].x,
            data[indices[c]].y
        };
    }

    for (int iter = 0; iter < maxIterations; ++iter) {
        bool changed = false;

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
                changed = true;
            }
        }

        if (!changed && iter > 0) {
            std::cout << "Convergiu na iteracao "
                      << iter + 1 << '\n';
            break;
        }

        // Calcula novos centroides.
        std::vector<Centroid> sums(k, {0.0, 0.0});
        std::vector<int> counts(k, 0);

        for (const auto& t : data) {
            int c = t.cluster;
            sums[c].x += t.x;
            sums[c].y += t.y;
            counts[c]++;
        }

        for (int c = 0; c < k; ++c) {
            if (counts[c] > 0) {
                centroids[c].x = sums[c].x / counts[c];
                centroids[c].y = sums[c].y / counts[c];
            } else {
                // Reposiciona um centroide vazio em um tweet aleatorio.
                int i = indices[rng() % n];
                centroids[c] = {data[i].x, data[i].y};
            }
        }

        if (iter == maxIterations - 1)
            std::cout << "Limite de iteracoes atingido.\n";
    }

}

int main(int argc, char const *argv[]) {
    // Ler instâncias transformando os dados para a estrutura
    Dataset dataset = readData();
    std::cout << "Timestamp em segundos:" << dataset[0].timestamp << std::endl;
    
    // Próximos passos (ex: separar em blocos / aplicar k-means para cada bloco) com MPI

    return 0;
}




