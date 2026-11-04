# Testes iniciais do K-means

Estes são casos manuais de correção. Os três casos foram executados e conferidos com 1, 2 e 4 processos. As evidências e limitações estão em [resultados da validação local](../resultados/validacao_local/README.md). Ainda não há um verificador automático

Os CSVs em `fixtures/` são sintéticos e já estão no formato lido pelo `main`: x e y em metros, tempo em segundos e uma coluna de fuso. O fuso não participa do agrupamento. O tempo começa artificialmente em zero; não representa a data de tweets reais.

Não rode `preprocess_data.py` nesses arquivos. Ele espera longitude, latitude e um timestamp de calendário, que são entradas diferentes.

## Resultados esperados

| Arquivo | k | Pontos | Resultado esperado na saída |
|---|---:|---:|---|
| `media.csv` | 1 | 4 | Um cluster com 4 pontos; x=3.0 m, y=6.0 m, t=1.5 h |
| `dimensao_constante.csv` | 1 | 4 | Um cluster com 4 pontos; x=10.0 m, y=5.0 m, t=1.5 h |
| `dois_grupos.csv` | 2 | 6 | Dois clusters de 3 pontos; centroides descritos abaixo |

Em `media.csv`, por exemplo, a média de x é `(0 + 2 + 4 + 6) / 4 = 3`. A média do tempo é 5.400 segundos, ou 1,5 hora após o início.

Para `dois_grupos.csv`, os centroides esperados, arredondados como na saída do programa, são:

- Grupo próximo da origem: x=0.7 m, y=0.7 m, t=0.0 h.
- Grupo mais distante: x=100.7 m, y=100.7 m, t=10.0 h.

Os IDs dos dois clusters podem estar invertidos. Confira o conteúdo dos grupos, não apenas o número do cluster. Se o caso de dois grupos não produzir o resultado esperado com a semente indicada, registre a diferença e investigue a inicialização e a execução; não marque como aprovado automaticamente.

## Executar primeiro com um processo

Requisitos: `make`, `mpic++` e `mpirun` disponíveis. Os comandos abaixo usam Bash e devem ser executados na raiz do repositório.

```bash
make
```

Depois de compilar com sucesso:

```bash
set -o pipefail
RODADA="resultados/local_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$RODADA"

mpirun -np 1 ./main tests/fixtures/media.csv 1 100 42 2>&1 | tee "$RODADA/media_np1.txt"
mpirun -np 1 ./main tests/fixtures/dimensao_constante.csv 1 100 42 2>&1 | tee "$RODADA/dimensao_constante_np1.txt"
mpirun -np 1 ./main tests/fixtures/dois_grupos.csv 2 100 42 2>&1 | tee "$RODADA/dois_grupos_np1.txt"
```

Conferir cada saída com a tabela. Todos devem informar convergência, conservar a quantidade de pontos e apresentar centroides finitos. Se um comando retornar erro, pare e investigue antes de prosseguir.

## Repetir com mais processos

Na mesma sessão Bash, depois de conferir os resultados com um processo:

```bash
for p in 2 4; do
    mpirun -np "$p" ./main tests/fixtures/media.csv 1 100 42 2>&1 | tee "$RODADA/media_np${p}.txt" || break
    mpirun -np "$p" ./main tests/fixtures/dimensao_constante.csv 1 100 42 2>&1 | tee "$RODADA/dimensao_constante_np${p}.txt" || break
    mpirun -np "$p" ./main tests/fixtures/dois_grupos.csv 2 100 42 2>&1 | tee "$RODADA/dois_grupos_np${p}.txt" || break
done
```

Use apenas quantidades de processos suportadas pelo ambiente/alocação. Se só puder executar com um ou dois processos, registre os demais como pendentes. No NPAD, estes comandos devem estar dentro de uma alocação apropriada e o lançador MPI deve seguir a configuração do ambiente.

O objetivo aqui é conferir os resultados. Esses arquivos são pequenos demais para tirar conclusões de desempenho; o programa pode até imprimir tempo `0.000 s` por causa do arredondamento.

## Documentar a execução

Anote o commit com `git rev-parse --short HEAD` e registre o ambiente, os casos aprovados, as falhas e os caminhos dos logs na tabela de [PLANO_TESTES.md](../docs/PLANO_TESTES.md).

Uma mensagem de convergência sozinha não basta: compare também as contagens e os centroides. Tempos, ordem das mensagens e número de iterações não precisam ser idênticos para os resultados numéricos serem compatíveis.
