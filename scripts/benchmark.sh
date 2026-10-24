#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DADOS=${DADOS:-src/data/twitter_processed.csv}
K=${K:-8}
MAX_ITER=${MAX_ITER:-300}
REPS=${REPS:-3}
NPS=${NPS:-"1 2 4 8 16"}
SEMENTE=${SEMENTE:-42}
SAIDA=resultados/medicoes.csv
NUCLEOS=$(lscpu -p=CORE | grep -v '^#' | sort -u | wc -l)

mkdir -p resultados
echo "processos,rep,leitura_s,kmeans_s" > "$SAIDA"

extrair() {
    awk '/Tempo de leitura/ {l=$4} /Tempo do k-means/ {k=$4} END {printf "%s,%s", l, k}'
}

for p in $NPS; do
    if (( p <= NUCLEOS )); then
        flags="--bind-to core"
    else
        flags="--use-hwthread-cpus"
    fi
    for r in $(seq "$REPS"); do
        echo "np=$p rep=$r" >&2
        saida=$(mpirun $flags -np "$p" ./main "$DADOS" "$K" "$MAX_ITER" "$SEMENTE")
        echo "$p,$r,$(echo "$saida" | extrair)" >> "$SAIDA"
    done
done

if [[ -x ./kmeans_cuda ]]; then
    for r in $(seq "$REPS"); do
        echo "gpu rep=$r" >&2
        saida=$(./kmeans_cuda "$DADOS" "$K" "$MAX_ITER" "$SEMENTE")
        echo "gpu,$r,$(echo "$saida" | extrair)" >> "$SAIDA"
    done
fi

echo "Medições salvas em $SAIDA" >&2
