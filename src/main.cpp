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

std::string FILE_NAME = "src/data/twitter.csv";

struct Tweet {
    double longitude;
    double latitude;
    long long timestamp;
    int timezone;
    int cluster = -1;
};

using Dataset = std::vector<Tweet>;

long long convertTimestampToSeconds(const std::string& timestamp_str) {
    int year   = std::stoi(timestamp_str.substr(0, 4));
        int month  = std::stoi(timestamp_str.substr(4, 2));
        int day    = std::stoi(timestamp_str.substr(6, 2));
        int hour   = std::stoi(timestamp_str.substr(8, 2));
        int minute = std::stoi(timestamp_str.substr(10, 2));
        int second = std::stoi(timestamp_str.substr(12, 2));

        std::tm tm_struct = {};
        tm_struct.tm_year = year - 1900; // Anos contados desde 1900
        tm_struct.tm_mon  = month - 1;   // Meses de 0 a 11
        tm_struct.tm_mday = day;
        tm_struct.tm_hour = hour;
        tm_struct.tm_min  = minute;
        tm_struct.tm_sec  = second;
        tm_struct.tm_isdst = -1;

        // Converte para segundos totais desde 1970
        std::time_t seconds = std::mktime(&tm_struct);
        return static_cast<long long>(seconds);
}

Dataset readData() {
    std::ifstream file(FILE_NAME);

    if (!file.is_open()) {
        std::cerr << "Erro ao abrir o arquivo: " << FILE_NAME << std::endl;
    }

    std::string line;
    int row_count = 0;
    Dataset dataset;

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
                Tweet t;
                t.longitude = std::stod(row_values[0]);
                t.latitude  = std::stod(row_values[1]);
                t.timestamp = convertTimestampToSeconds(row_values[2]);
                t.timezone  = std::stoi(row_values[3]);

                dataset.push_back(t);
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

double distanceSquared(const Tweet& a, const Tweet& b){
    double dx = a.longitude - b.longitude;
    double dy = a.latitude - b.latitude;
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




