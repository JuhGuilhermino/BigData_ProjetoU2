# K-means com MPI sobre o Twitter Geospatial Data

Projeto da disciplina Sistemas Big Data (UFRN). Implementação do algoritmo **K-means paralelo com MPI** (C++) aplicado a 14.262.517 tweets geolocalizados dos EUA. Há também uma versão extra em CUDA (GPU) para comparação.

## Dados

[Twitter Geospatial Data (UCI)](https://archive.ics.uci.edu/dataset/1050/twitter+geospatial+data): uma semana de tweets geolocalizados (12 a 18/01/2013), sem o texto, só onde e quando.

| Coluna | Descrição |
|---|---|
| `longitude`, `latitude` | posição do tweet |
| `timestamp` | `AAAAMMDDhhmmss`, horário CST |
| `timezone` | 1 Eastern, 2 Central, 3 Mountain, 4 Pacific |

A análise exploratória está em [RESULTADOS_EDA.md](RESULTADOS_EDA.md) (código em `src/EDA/eda.py`).

## Estrutura

```
src/main.cpp              K-means com MPI
src/kmeans_cuda.cu        K-means em CUDA (extra)
src/preprocess_data.py    prepara o CSV (timestamp em segundos, projeção em metros)
src/desempenho.py         tabela e gráficos de speedup e eficiência
src/EDA/eda.py            análise exploratória
scripts/pipeline.sh       executa todas as etapas
scripts/benchmark.sh      mede o tempo variando o número de processos
Makefile
```

## Plano de testes

O plano de validação e dos experimentos está em [docs/PLANO_TESTES.md](docs/PLANO_TESTES.md).
Ele separa os testes de correção das medições de desempenho e registra o que ainda precisa ser executado.

## Requisitos

- Open MPI (`sudo apt install openmpi-bin libopenmpi-dev`) e g++ com C++17
- [uv](https://docs.astral.sh/uv/) para o ambiente Python
- CUDA Toolkit (opcional, só para a versão GPU)

## Pipeline de execução

Coloque o `twitter.csv` descompactado em `src/data/` e, na raiz do projeto, rode:

```bash
make pipeline
```

(equivalente a `bash scripts/pipeline.sh`). Ele executa, nesta ordem:

1. verifica as ferramentas;
2. gera `src/data/twitter_processed.csv` (pula se já existir);
3. compila o `main` (e o `kmeans_cuda`, se houver `nvcc`);
4. executa uma vez com 4 processos e salva a saída em `resultados/execucao.txt`;
5. mede o tempo de cada configuração de processos (`resultados/medicoes.csv`);
6. gera a tabela `resultados/desempenho.md` e os gráficos `resultados/desempenho.png`.

Parâmetros opcionais, por variável de ambiente:

| Variável | Padrão | O que faz |
|---|---|---|
| `K` | 8 | número de clusters |
| `MAX_ITER` | 300 | máximo de iterações |
| `NPS` | `"1 2 4 8 16"` | números de processos medidos |
| `REPS` | 3 | repetições por configuração (o relatório usa a mediana) |
| `SEMENTE` | 42 | semente do sorteio dos centroides |

Exemplo: `K=16 NPS="1 2 4" REPS=5 make pipeline`.

A execução termina com "Convergiu na iteracao N" ou "Limite de iteracoes atingido". Todas as configurações de processos executam exatamente as mesmas iterações, então os tempos são comparáveis; se aparecer o limite, aumente `MAX_ITER` e informe isso no relatório.

### Execução manual

```bash
uv run src/preprocess_data.py
make
mpirun --bind-to core -np 4 ./main src/data/twitter_processed.csv 8 300 42
```

Argumentos do `./main`: `arquivo.csv`, `k` (padrão 8), máximo de iterações (padrão 100) e semente (padrão 42). A saída traz o tamanho e o centroide de cada cluster (em metros, e o tempo em horas após o início dos dados) e os tempos de leitura e do K-means.

`--bind-to core` fixa cada processo em um núcleo físico. Para usar mais processos que núcleos físicos, troque por `--use-hwthread-cpus` (o `benchmark.sh` faz isso automaticamente).

Versão GPU:

```bash
make cuda
./kmeans_cuda src/data/twitter_processed.csv 8 300 42
```

## Preparação dos dados

- **Timestamp:** o `AAAAMMDDhhmmss` é convertido em um único atributo em segundos desde 1970. O `timezone` não entra no agrupamento: o horário já está numa única base (CST) e o fuso é consequência da posição.
- **Projeção:** longitude e latitude (graus) são convertidas para metros (EPSG:5070, projeção de área igual para os EUA), para que distâncias euclidianas tenham sentido físico.
- **Normalização:** cada um dos três atributos (x, y, tempo) é normalizado por min-max para [0, 1] dentro do `main.cpp`, para que nenhum domine a distância por causa da escala. Os mínimos e máximos são globais, calculados com `MPI_Allreduce`.

O agrupamento usa então 3 dimensões: posição (x, y) e tempo, com o mesmo peso. Por isso cada cluster tende a ser uma região em uma janela de tempo.

## Distribuição do processamento (MPI)

1. **Leitura paralela.** O arquivo é dividido em faixas de bytes, uma por processo. Cada processo lê apenas as linhas que *começam* dentro da sua faixa, então nenhuma linha é perdida ou lida duas vezes. Os dados ficam distribuídos desde a leitura, sem um processo centralizar tudo e depois enviar.
2. **Normalização.** Cada processo calcula mínimo e máximo locais; `MPI_Allreduce` (MIN e MAX) obtém os globais e cada processo normaliza os seus tweets.
3. **Centroides iniciais.** Todos sorteiam os mesmos `k` índices globais (mesma semente); o processo dono de cada tweet sorteado preenche as suas coordenadas e um `MPI_Allreduce(SUM)` entrega o resultado a todos. Como os índices seguem a ordem do arquivo, o ponto de partida não depende do número de processos: 1, 2, 4 ou 16 processos executam exatamente o mesmo algoritmo, o que torna a comparação de tempo justa.
4. **A cada iteração:**
   - cada processo atribui os seus tweets ao centroide mais próximo (parte local, sem comunicação);
   - `MPI_Allreduce(MAX)` verifica se algum tweet em algum processo mudou de cluster; se nenhum mudou, o algoritmo convergiu;
   - cada processo soma x, y e tempo e conta os tweets por cluster; `MPI_Allreduce(SUM)` junta as somas e todos calculam os mesmos novos centroides.
5. **Resultado.** Os tamanhos dos clusters são somados com `MPI_Reduce` e os tempos reportados são os do processo mais lento (`MPI_MAX`). "Tempo de leitura" inclui a normalização.

A comunicação por iteração é de poucos bytes (`k` centroides com 3 valores), então o custo é dominado pelo cálculo local. Os centroides vazios mantêm a posição anterior, o que os mantém iguais em todos os processos.

## Versão GPU (extra)

`src/kmeans_cuda.cu` executa o mesmo algoritmo (mesma normalização, semente e sorteio de centroides) em uma GPU NVIDIA: os dados vão para a placa uma única vez e um kernel faz, a cada iteração, a atribuição e a soma parcial por cluster. O tempo da cópia para a GPU é impresso à parte e não entra na tabela de desempenho. Aceita no máximo `k = 800`.
