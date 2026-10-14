#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

std::string FILE_NAME = "src/data/twitter.csv";

struct Data {
    double longitude;
    double latitude;
    long long timestamp;
    int timezone;
};

std::vector<Data> readData(const std::vector<Data> dataset) {
    std::ifstream file(FILE_NAME);

    if (!file.is_open()) {
        std::cerr << "Erro ao abrir o arquivo: " << filename << std::endl;
        return;
    }

    std::string line;
    int row_count = 0;
    std::vector<Data> dataset;

    // Ignora cabeçalho
    if (std::getline(file, line)) { }

    // Lê arquivo linha por linha
    while (std::getline(file, line)) {
        if (line.empty()) continue;

        row_count++;
        std::stringstream ss(line);
        std::string cell;
        std::vector<std::string> row_values;

        while (std::getline(ss, cell, ',')) {
            row_values.push_back(cell);
        }

        if (row_values.size() >= 4) {
            try {
                Data entry;
                entry.longitude = std::stod(row_values[0]);
                entry.latitude  = std::stod(row_values[1]);
                entry.timestamp = std::stod(row_values[2]);
                entry.timezone  = std::stoi(row_values[3]);

                dataset.push_back(entry);
            } catch (const std::exception& e) {
                std::cerr << "Erro de conversão na linha " << row_count << ": " << e.what() << std::endl;
            }
        } else {
            std::cerr << "Aviso: Linha " << row_count << " tem menos de 4 colunas." << std::endl;
        }
    }

    file.close();

    std::cout << "Leitura concluída com sucesso! Total de registos carregados: " << dataset.size() << std::endl;

    return dataset;
}

int main(int argc, char const *argv[]) {
    // Ler instâncias transformando os dados para a estrutura
    std::vector<Data> dataset = readData(dataset);
    

    // Próximos passos (ex: separar em blocos / aplicar k-means) entram aqui...

    return 0;
}




