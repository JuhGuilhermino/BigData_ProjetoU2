# Resultados – K-means na CPU (MPI) vs GPU (CUDA)

Execução de 2026-11-03, conforme registro fornecido. Dados brutos em [medicoes.csv](medicoes.csv). Este documento usa médias aritméticas; [desempenho.md](desempenho.md), gerado por `src/desempenho.py`, usa medianas. As diferenças entre essas tabelas decorrem da estatística utilizada.

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

O registro fornecido informa convergência na iteração 262 em todas as configurações e coincidência das contagens e dos centroides impressos com os apresentados em [resultados_gpu.md](resultados_gpu.md). Essa observação se limita aos dados, parâmetros e à precisão de saída registrados; não garante independência do número de processos para qualquer entrada. O CSV contém apenas tempos e não permite conferir essa afirmação sem os logs completos.

## Observações

- Até 4 processos o escalonamento é quase linear (eficiência > 93%).
- Com 8 e 16 processos a eficiência cai. Possíveis causas: o laptop tem só 6 P-cores, os E-cores são mais lentos e, com 16 processos, há threads irmãs no mesmo núcleo. Também pesa a sincronização (Allreduce) a cada iteração. Essas causas são hipóteses; não foram medidas.
- A GPU faz o k-means em 4,95 s, 1,40x mais rápido que 16 processos MPI (6,95 s) e 8,3x mais rápido que 1 processo.
- A leitura do CSV na GPU (3,83 s) é feita em um único processo e equivale ao MPI com 1 processo. No MPI a leitura é paralela e cai para 0,45 s com 16 processos. No tempo total (leitura + k-means), a GPU leva 8,78 s e o MPI com 16 processos, 7,39 s.

## Limites da comparação

- O total citado acima é a soma dos tempos médios de leitura e K-means. Não inclui a cópia para a GPU, compilação, pré-processamento nem todo o custo de iniciar a execução.
- Os tempos CUDA deste resumo vêm de `medicoes.csv`. Os três tempos em `resultados_gpu.md` são diferentes; a origem dessa diferença ainda precisa ser confirmada, sem juntar os registros como se fossem as mesmas repetições.
- O ambiente informado é um notebook. Estes resultados não documentam uma execução no NPAD.
- Ainda faltam o commit do código executado, o hash do CSV de entrada, as versões do compilador/MPI do benchmark e os logs completos das repetições. O commit da validação sintética não identifica automaticamente esta rodada.
