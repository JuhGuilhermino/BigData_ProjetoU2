#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include <ctime>
#include <iomanip>
#include <random>
#include <numeric>
#include <stdexcept>

struct Tweet {
    long long x;
    long long y;
    long long timestamp;
    int timezone;
    int cluster = -1;
};

std::string FILE_NAME = "src/data/twitter_processed.csv";

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

        // Teste de leitura dos dados
        std::cout << "X: " << t.x << ", Y: " << t.y << ", Timestamp: " << t.timestamp << ", Timezone: " << t.timezone << '\n';

    }

    file.close();

    std::cout << "Leitura concluída com sucesso! Total de registos carregados: " << dataset.size() << std::endl;

    return dataset;
}

double distanceSquared(const Tweet& a, const Tweet& b){
    double dx = a.x - b.y;
    double dy = a.x - b.y;
    return dx * dx + dy * dy;
}

//void kmeans2D(const std::vector<Data>)

int main(int argc, char const *argv[]) {
    // Ler instâncias transformando os dados para a estrutura
    Dataset dataset = readData();
    std::cout << "Timestamp em segundos:" << dataset[0].timestamp << std::endl;
    
    // Próximos passos (ex: separar em blocos / aplicar k-means para cada bloco) com MPI

    return 0;
}




