# Resultados – K-means na CPU (MPI) vs GPU (CUDA)

Execução de 2026-11-03. Dados brutos em `medicoes.csv`.

## Ambiente

- CPU: i5-13450HX (6 P-cores + 4 E-cores, 16 threads); GPU: RTX 4050 Laptop (5772 MB)
- Dados: `src/data/twitter_processed.csv`, 14.262.517 tweets, 3D normalizado (x, y, tempo)
- Parâmetros: k = 8, máx. 300 iterações, semente 42, 3 repetições por configuração
- Binding: `--bind-to core` até 10 processos; `--use-hwthread-cpus` para 16

## Tempos médios

| Execução | Leitura (s) | K-means (s) | Speedup (k-means) | Eficiência |
|---|---|---|---|---|
| MPI, 1 processo | 3,889 | 40,952 | 1,00 | 100,0% |
| MPI, 2 processos | 1,907 | 21,300 | 1,92 | 96,1% |
| MPI, 4 processos | 1,002 | 10,962 | 3,74 | 93,4% |
| MPI, 8 processos | 0,723 | 8,338 | 4,91 | 61,4% |
| MPI, 16 processos | 0,448 | 6,945 | 5,90 | 36,9% |
| GPU (RTX 4050) | 3,833 | 4,949 | 8,27 | – |

Speedup = tempo com 1 processo / tempo da configuração.

## Resultado

Em todas as configurações o k-means convergiu na iteração 262, com os mesmos 8 clusters e centroides da execução na GPU (ver `resultados_gpu.md`). Ou seja, o resultado não depende do número de processos.

## Observações

- Até 4 processos o escalonamento é quase linear (eficiência > 93%).
- Com 8 e 16 processos a eficiência cai. Possíveis causas: o laptop tem só 6 P-cores, os E-cores são mais lentos e, com 16 processos, há threads irmãs no mesmo núcleo. Também pesa a sincronização (Allreduce) a cada iteração. Essas causas são hipóteses; não foram medidas.
- A GPU faz o k-means em 4,95 s, 1,40x mais rápido que 16 processos MPI (6,95 s) e 8,3x mais rápido que 1 processo.
- A leitura do CSV na GPU (3,83 s) é feita em um único processo e equivale ao MPI com 1 processo. No MPI a leitura é paralela e cai para 0,45 s com 16 processos. No tempo total (leitura + k-means), a GPU leva 8,78 s e o MPI com 16 processos, 7,39 s.
