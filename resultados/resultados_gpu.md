# Resultados – K-means na GPU (CUDA)

Execução de 2026-11-03, conforme registro fornecido. Os tempos abaixo diferem dos três registros CUDA em [medicoes.csv](medicoes.csv). A origem dessa diferença precisa ser confirmada; os valores originais foram preservados. A comparação consolidada MPI/CUDA em [desempenho.md](desempenho.md) usa exclusivamente o CSV.

## Ambiente

| Item | Valor |
|---|---|
| GPU | NVIDIA GeForce RTX 4050 Laptop GPU (5772 MB) |
| Driver | 595.99.02 |
| Binário | `kmeans_cuda` (`make cuda`, `nvcc -O2 -std=c++17 -arch=native`) |
| Dados | `src/data/twitter_processed.csv` (14.262.517 tweets) |
| Parâmetros | k = 8, máx. 300 iterações, semente 42 |
| Espaço de atributos | 3D normalizado (x, y, tempo), min-max |

Comando:

```bash
./kmeans_cuda src/data/twitter_processed.csv 8 300 42
```

## Tempos (3 execuções)

| Execução | Leitura (s) | Cópia p/ GPU (s) | K-means (s) |
|---|---|---|---|
| 1 | 3,886 | 0,141 | 4,962 |
| 2 | 3,824 | 0,120 | 4,943 |
| 3 | 3,838 | 0,150 | 4,969 |
| **Média** | **3,849** | **0,137** | **4,958** |

- O registro informa convergência na iteração **262** nas três execuções. A repetição desse resultado nas condições observadas não prova determinismo em qualquer ambiente ou entrada.
- Tempo médio por iteração: ≈ 18,9 ms.
- Entre as etapas medidas, o K-means tem o maior tempo médio: 4,958 s, contra 3,849 s da leitura e 0,137 s da cópia. A soma dessas médias é 8,944 s; a leitura responde por aproximadamente 43% e o K-means por 55% dessa soma. Esse valor não mede todo o tempo da pipeline.

## Clusters (reportados como iguais nas três execuções, na precisão impressa)

| Cluster | Tweets | x (m) | y (m) | t (h após o início) |
|---|---|---|---|---|
| 0 | 2.306.017 | 1.225.786,6 | 2.065.140,8 | 28,6 |
| 1 | 2.407.688 | 1.234.913,4 | 2.053.330,3 | 82,2 |
| 2 | 1.436.137 | 625.279,3 | 1.031.138,4 | 28,8 |
| 3 | 1.195.896 | -1.818.076,0 | 1.810.351,2 | 41,2 |
| 4 | 2.570.519 | 1.225.847,1 | 2.065.198,3 | 139,4 |
| 5 | 1.262.018 | -1.824.524,3 | 1.797.019,4 | 125,9 |
| 6 | 1.457.948 | 590.879,7 | 1.028.363,2 | 82,0 |
| 7 | 1.626.294 | 665.599,3 | 1.037.589,8 | 139,1 |

Total: 14.262.517 tweets.

## Observações

- Os clusters se separam principalmente por região (três grupos espaciais: ≈ (1,23M; 2,06M), ≈ (0,6M; 1,03M) e ≈ (-1,82M; 1,8M) m) e por faixa de tempo.
- Este registro específico da GPU não contém uma medição MPI pareada. A comparação disponível no projeto está em `medicoes.csv` e `desempenho.md`.
- Os centroides e as contagens são um resumo dos grupos. Uma visualização dos pontos coloridos por cluster exige exportar também os rótulos individuais.
