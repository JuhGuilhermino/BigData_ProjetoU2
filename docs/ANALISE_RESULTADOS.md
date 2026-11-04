# Análise dos testes e resultados

Este texto reúne a validação e a análise de desempenho para integração ao relatório do grupo. As medições de desempenho foram fornecidas por Flávio; a validação sintética e a organização das evidências foram realizadas por Kauã. Os resultados descritos se limitam aos arquivos registrados no repositório.

## Validação de correção

Foram utilizados três conjuntos sintéticos com resultados esperados calculáveis manualmente: média de quatro pontos com um único cluster, dimensão espacial constante e dois grupos separados com três pontos cada. Cada caso foi executado com 1, 2 e 4 processos MPI, totalizando nove execuções, com semente 42 e limite de 100 iterações.

| Caso | Pontos | k | Centroides observados: x (m), y (m), t (h após o início) | Iterações |
|---|---:|---:|---|---:|
| Média | 4 | 1 | (3,0; 6,0; 1,5) | 2 |
| Dimensão constante | 4 | 1 | (10,0; 5,0; 1,5) | 2 |
| Dois grupos separados | 6 | 2 | (0,7; 0,7; 0,0) e (100,7; 100,7; 10,0) | 3 |

Todas as execuções informaram convergência. As contagens, os centroides impressos e o número de iterações coincidiram entre as quantidades de processos testadas. Não foram observados valores NaN ou infinitos nas coordenadas impressas. No caso de dois grupos, cada cluster reuniu três pontos.

A comparação foi manual e considerou uma casa decimal, que é a precisão da saída. Esses testes fornecem evidência de correção para os casos avaliados, mas não cobrem todas as entradas inválidas, situações de leitura distribuída ou clusters vazios. Os tempos impressos como `0.000 s` não foram usados para avaliar desempenho.

As evidências estão em [validacao_local](../resultados/validacao_local/README.md), referentes ao commit `20311394b802c6f9a76021149ec4e8c869851c2a`. O ambiente registrado utilizou Open MPI 4.1.2 e g++ 11.4.0 (Ubuntu).

## Metodologia do experimento de desempenho

O ambiente informado para as medições foi um notebook com Intel Core i5-13450HX, composto por seis P-cores e quatro E-cores, com 16 threads, e GPU NVIDIA GeForce RTX 4050 Laptop com 5772 MB. Foram utilizados 14.262.517 tweets, representados por posição projetada (x e y) e tempo, com normalização min-max. Os parâmetros informados foram oito clusters, semente 42 e limite de 300 iterações.

O arquivo [medicoes.csv](../resultados/medicoes.csv) contém três repetições para cada configuração MPI de 1, 2, 4, 8 e 16 processos, além de três repetições CUDA. São 18 medições ao todo. O resumo do experimento informa afinidade por núcleo físico até dez processos e uso de threads de hardware na configuração com 16 processos. Estes registros não documentam uma execução no NPAD.

A análise utiliza a mediana das três repetições, calculada por `src/desempenho.py`. O speedup do K-means é a razão entre a mediana com um processo MPI e a mediana da configuração avaliada. A eficiência MPI é o speedup dividido pelo número de processos. Não se calcula eficiência CUDA dividindo pelo número de núcleos da GPU, pois essa comparação não corresponde à definição utilizada para os processos MPI.

Para cada repetição, o total é definido como leitura mais K-means. A mediana é calculada sobre esses totais individuais; portanto, não precisa ser igual à soma das medianas de leitura e de K-means. O total exclui a cópia dos dados para a GPU e as demais etapas da pipeline. O tempo de leitura MPI inclui a normalização.

## Resultados de desempenho

| Processos | Leitura (s) | K-means (s) | Total (s) | Speedup K-means | Eficiência K-means | Speedup total |
|---|---|---|---|---|---|---|
| 1 | 3.89 | 40.96 | 44.87 | 1.00x | 100% | 1.00x |
| 2 | 1.90 | 21.28 | 23.22 | 1.92x | 96% | 1.93x |
| 4 | 1.00 | 10.98 | 11.99 | 3.73x | 93% | 3.74x |
| 8 | 0.72 | 8.35 | 9.06 | 4.90x | 61% | 4.95x |
| 16 | 0.46 | 6.87 | 7.33 | 5.96x | 37% | 6.12x |
| GPU | 3.84 | 4.95 | 8.79 | 8.28x | - | 5.10x |

Fonte: `medicoes.csv`, processado por `src/desempenho.py`. Tempos em segundos; os valores desta tabela são medianas. O resumo `resultados_cpu.md` utiliza médias e deve ser identificado dessa forma quando citado.

O tempo mediano do K-means caiu de 40,96 s com um processo para 6,87 s com 16 processos. O speedup correspondente foi de 5,96 vezes, com eficiência de aproximadamente 37%. Até quatro processos, o ganho ficou próximo do crescimento proporcional, com speedup de 3,73 e eficiência de 93%. Com oito e 16 processos, o tempo continuou diminuindo, porém o ganho adicional foi menor em relação ao aumento de recursos.

O processador combina núcleos de desempenhos diferentes e, com 16 processos, utiliza threads de hardware em núcleos compartilhados. Essa característica, juntamente com os custos de sincronização das operações coletivas MPI, pode contribuir para a queda de eficiência. As medições disponíveis não isolam esses fatores; portanto, eles são hipóteses explicativas, não causas comprovadas.

A GPU apresentou mediana de 4,95 s para o K-means e speedup de 8,28 em relação ao MPI com um processo. Entretanto, considerando a soma medida de leitura e K-means, o MPI com 16 processos apresentou 7,33 s, enquanto a GPU apresentou 8,79 s. Assim, a vantagem da GPU na etapa de cálculo não resultou no menor tempo dessa soma de etapas. Essa comparação ainda exclui a transferência para a GPU e não representa o tempo completo da aplicação.

Os [gráficos disponíveis](../resultados/desempenho.png) apresentam o speedup e a eficiência MPI. A tabela também permite observar a queda do tempo de leitura conforme cresce a quantidade de processos.

## Convergência e limites das evidências

Os resumos de execução fornecidos informam convergência na iteração 262, abaixo do limite de 300, e concordância dos resultados impressos nas configurações descritas. O CSV de tempos não contém o estado de convergência nem os centroides; sem os logs completos, essa informação depende dos resumos fornecidos.

Os tempos CUDA de `resultados_gpu.md` diferem dos tempos CUDA em `medicoes.csv`. Para manter uma fonte consistente, toda a tabela de desempenho desta análise foi calculada somente a partir do CSV. A origem da diferença entre os registros ainda precisa ser confirmada, sem substituir ou combinar silenciosamente os valores.

As principais limitações são o número de três repetições por configuração, a avaliação em um único equipamento e a ausência de registros suficientes para isolar efeitos de cache, temperatura, carga concorrente e sincronização. Também faltam o commit efetivamente usado no benchmark, o hash do arquivo de entrada, as versões do compilador/MPI desse ambiente e as saídas completas de cada repetição. O hash da validação sintética não deve ser usado para preencher essas lacunas.

Os oito clusters documentados no resumo GPU somam 14.262.517 tweets. Os centroides sugerem separação espacial e temporal, mas não mostram a distribuição interna de cada grupo. A visualização de pontos por cluster depende da exportação dos rótulos individuais; os mapas da análise exploratória não substituem essa visualização.

Os resultados sustentam a consistência dos três casos sintéticos avaliados e mostram redução do tempo de cálculo com o aumento dos processos MPI no equipamento informado. A escalabilidade é limitada nas configurações maiores, e a comparação com CUDA depende das etapas incluídas na medição. A validação de correção e o experimento de desempenho respondem a perguntas diferentes e são contribuições complementares para o relatório.
