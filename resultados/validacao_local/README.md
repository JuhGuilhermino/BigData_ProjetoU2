# Validação local do K-means com MPI

Em 29/10/2026, executamos três casos sintéticos com 1, 2 e 4 processos, totalizando nove execuções. Usamos semente 42 e limite de 100 iterações.

O objetivo foi conferir a correção em entradas pequenas e comparar os resultados entre diferentes quantidades de processos.

## Resultados

| Caso | k | Pontos | Centroide esperado (x, y, tempo em horas) | Iterações | Processos aprovados |
|---|---:|---:|---|---:|---|
| Média | 1 | 4 | (3.0, 6.0, 1.5) | 2 | 1, 2 e 4 |
| Dimensão constante | 1 | 4 | (10.0, 5.0, 1.5) | 2 | 1, 2 e 4 |
| Dois grupos | 2 | 6 | (0.7, 0.7, 0.0) e (100.7, 100.7, 10.0) | 3 | 1, 2 e 4 |

Todas as execuções informaram convergência. As contagens e os centroides impressos corresponderam aos valores esperados. No caso de dois grupos, cada cluster ficou com três pontos.

A dimensão constante manteve x=10.0, sem NaN ou infinito na saída.

## Evidências

Os arquivos seguem o padrão `<caso>_np<processos>.txt` e contêm a saída completa de cada execução.

## Limitações

A comparação dos centroides considera a precisão impressa pelo programa: uma casa decimal.

Esses resultados validam somente os casos sintéticos executados. Ainda faltam testes de entradas inválidas, pré-processamento e execução com os dados reais.

Foi feita uma execução registrada por caso e quantidade de processos. Esta rodada não é um benchmark: os dados são pequenos e o tempo do K-means apareceu arredondado para 0.000 s.

As medições de desempenho e os experimentos no NPAD continuam pendentes.
