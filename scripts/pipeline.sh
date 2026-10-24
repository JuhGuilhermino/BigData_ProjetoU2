#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BRUTO=src/data/twitter.csv
export DADOS=src/data/twitter_processed.csv
export K=${K:-8}
export MAX_ITER=${MAX_ITER:-300}
export REPS=${REPS:-3}
export NPS=${NPS:-"1 2 4 8 16"}
export SEMENTE=${SEMENTE:-42}

etapa() {
    echo
    echo "=== $1 ==="
}

etapa "1/6 Verificando ferramentas"
for cmd in mpic++ mpirun uv make; do
    if ! command -v "$cmd" > /dev/null; then
        echo "Erro: '$cmd' não encontrado. Veja a seção Requisitos do README." >&2
        exit 1
    fi
done
echo "ok"

etapa "2/6 Preparando os dados"
if [[ -f "$DADOS" ]]; then
    echo "$DADOS já existe, pulando o pré-processamento"
elif [[ -f "$BRUTO" ]]; then
    uv run src/preprocess_data.py
else
    echo "Erro: coloque o twitter.csv em $BRUTO" >&2
    echo "Download: https://archive.ics.uci.edu/dataset/1050/twitter+geospatial+data" >&2
    exit 1
fi

etapa "3/6 Compilando"
make
if command -v nvcc > /dev/null; then
    make cuda
else
    echo "nvcc não encontrado, a versão GPU será ignorada"
fi

etapa "4/6 Execução de referência (4 processos, k=$K)"
mkdir -p resultados
mpirun --bind-to core -np 4 ./main "$DADOS" "$K" "$MAX_ITER" "$SEMENTE" | tee resultados/execucao.txt

etapa "5/6 Medindo o desempenho ($REPS repetições por configuração: $NPS)"
bash scripts/benchmark.sh

etapa "6/6 Gerando tabela e gráficos"
uv run src/desempenho.py

echo
echo "Pronto. Resultados em resultados/:"
echo "  execucao.txt    clusters e centroides da execução de referência"
echo "  medicoes.csv    tempos brutos de cada repetição"
echo "  desempenho.md   tabela de speedup e eficiência"
echo "  desempenho.png  gráficos de speedup e eficiência"
