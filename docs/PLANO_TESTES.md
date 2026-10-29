# Plano de testes — K-means com MPI

## Objetivo

A ideia é conferir primeiro se o programa agrupa os dados corretamente. Depois disso, medir o que muda no tempo de execução quando aumentamos o número de processos.

A validação inicial com dados sintéticos foi concluída localmente em 29/10/2026. Os três casos foram executados com 1, 2 e 4 processos e tiveram os resultados conferidos manualmente. Os testes adicionais, as medições de desempenho e a execução no NPAD continuam pendentes.

## 1. Validação com dados pequenos

Começamos com dados sintéticos, pequenos o suficiente para calcular os resultados esperados à mão. Eles servem para testar o algoritmo, não representam tweets reais e não passam pelo pré-processamento.

| Caso | Configuração | O que conferir | Situação |
|---|---|---|---|
| Média dos pontos | 4 pontos e `k=1` | Todos no mesmo cluster; centroide igual à média | Aprovado com 1, 2 e 4 processos |
| Dimensão constante | 4 pontos, `k=1` e x constante | Sem NaN/infinito na saída; x do centroide mantém o valor | Aprovado com 1, 2 e 4 processos |
| Dois grupos separados | 6 pontos e `k=2` | Dois grupos de 3 pontos e centroides esperados | Aprovado com 1, 2 e 4 processos |
| Variação dos processos | Repetir os três casos com 1, 2 e 4 processos | Mesmo total de pontos e resultados compatíveis | Aprovado nos três casos |

Os comandos, arquivos de entrada e valores esperados estão em `tests/`. Não é necessário o dataset completo nem o NPAD para esses testes: basta uma máquina com MPI e compilador C++.

Critérios usados na conferência:

- A execução termina sem erro e informa convergência.
- A soma dos tamanhos dos clusters é igual à quantidade de registros de entrada.
- Os centroides são compatíveis com os valores esperados.
- Mudar a quantidade de processos preserva as contagens e os centroides impressos nos casos testados.
- Não aparecem coordenadas NaN ou infinitas.

O programa imprime centroides com uma casa decimal. Na conferência manual, comparamos com os valores esperados também arredondados para uma casa. Quando houver exportação com maior precisão, será necessário definir uma tolerância numérica explícita para a comparação automática.

Os números dos clusters são apenas identificadores. Dois resultados podem representar os mesmos grupos com os IDs trocados.

### Resultados observados

Nas nove execuções registradas, usamos semente `42` e limite de `100` iterações. Cada linha abaixo resume os resultados com 1, 2 e 4 processos.

| Caso | Distribuição dos pontos | Centroide(s): x em metros, y em metros e tempo em horas após o início | Iterações até convergir |
|---|---|---|---:|
| Média dos pontos | 4 pontos no mesmo cluster | (3.0, 6.0, 1.5) | 2 |
| Dimensão constante | 4 pontos no mesmo cluster | (10.0, 5.0, 1.5) | 2 |
| Dois grupos separados | 3 pontos em cada cluster | (0.7, 0.7, 0.0) e (100.7, 100.7, 10.0) | 3 |

Todas as execuções informaram convergência. As contagens, os centroides impressos e o número de iterações coincidiram entre as configurações desses casos.

Isso confirma a consistência dos resultados observados nesses dados pequenos. A contagem total, sozinha, não prova a ausência de toda perda ou duplicação na leitura; os testes específicos da leitura distribuída continuam pendentes.

O tempo do K-means apareceu como `0.000 s` em todas as saídas, devido à precisão de impressão. Estes dados são pequenos demais para avaliar desempenho e esta rodada não foi usada para calcular speedup ou eficiência.

## 2. Próximos testes de correção

- Entradas inválidas: `k=0`, `k` maior que o número de pontos, arquivo inexistente e arquivo sem registros.
- Limite de iterações zero ou negativo: primeiro corrigir a validação, pois o código atual pode acessar um índice inválido.
- Limite de uma iteração: conferir se a saída informa que o limite foi atingido.
- Pontos repetidos e clusters vazios.
- Pré-processamento: linhas válidas/inválidas, contagem antes/depois e valores finitos após a projeção.
- Leitura distribuída: linhas de tamanhos diferentes, último registro sem quebra de linha e processos sem registros locais.

Esses casos ainda precisam ser implementados. Passar nos três casos iniciais não comprova que todas as entradas são tratadas corretamente.

## 3. Desempenho

Esta etapa ainda não foi executada. Depois de ampliar a validação de correção, executar o mesmo conjunto de dados com diferentes quantidades de processos.

| Parâmetro | Proposta inicial |
|---|---|
| Dados | Mesmo arquivo processado em todas as configurações |
| Clusters | `k=8` |
| Semente | `42` |
| Processos | `1 2 4 8 16`, limitados aos recursos alocados |
| Repetições | 5 por configuração |
| Limite de iterações | Começar em 300 e conferir a convergência |
| Referência | A própria implementação MPI com 1 processo |
| Resumo | Mediana, mínimo e máximo dos tempos |

Manter os parâmetros iguais na comparação. Se for preciso aumentar o limite de iterações, repetir o conjunto comparável de medições com a nova configuração. Não misturar silenciosamente execuções convergidas com execuções interrompidas pelo limite.

O speedup será calculado como `T1 / Tp`; a eficiência, como `speedup / p`. Analisar separadamente o tempo do K-means e o tempo de leitura + K-means. Esse último não inclui todo o tempo da pipeline, como pré-processamento e compilação.

Registrar em cada experimento:

- Commit utilizado, data, máquina/nós e recursos alocados.
- Versões do compilador e MPI e opções de compilação.
- Arquivo de entrada, hash SHA-256 e quantidade de pontos válidos.
- Quantidade de processos, k, semente e limite de iterações.
- Saída completa de cada repetição, tempos, número de iterações e estado de convergência.

No NPAD, ainda precisamos preparar o script de submissão e conferir os módulos e os recursos disponíveis. Os benchmarks devem rodar nos recursos de computação alocados. Resultados locais ficam separados dos resultados do NPAD.

## 4. Entregas da parte de testes

- [x] Três casos pequenos com entradas, resultados esperados e nove logs de execução local.
- [ ] Testes adicionais de correção, incluindo entradas inválidas e leitura distribuída.
- [ ] Medições de desempenho e logs de cada repetição.
- [ ] Tabela e gráficos de tempo, speedup e eficiência com as medições finais.
- [ ] Visualização de uma amostra dos pontos por cluster e distribuição temporal.
- [ ] Texto do relatório explicando ambiente, metodologia, resultados e limitações.

Para desenhar os clusters, ainda falta exportar os rótulos dos pontos e os centroides. A versão CUDA fica como experimento extra, depois da validação do MPI.

## 5. Registro de execução

Os logs desta rodada foram salvos em `resultados/validacao_local/`. Cada configuração tem uma execução registrada. Nas próximas rodadas, usar pastas diferentes, por exemplo `resultados/local_<data>/` ou `resultados/npad_<job>/`, para preservar as evidências anteriores.

| Data | Commit | Ambiente | Caso/configuração | Resultado observado | Log |
|---|---|---|---|---|---|
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Média; k=1; np=1, 2 e 4 | Aprovado; 4 pontos; convergência em 2 iterações | `resultados/validacao_local/media_np{1,2,4}.txt` |
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Dimensão constante; k=1; np=1, 2 e 4 | Aprovado; 4 pontos; convergência em 2 iterações | `resultados/validacao_local/dimensao_constante_np{1,2,4}.txt` |
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Dois grupos; k=2; np=1, 2 e 4 | Aprovado; 3 pontos por cluster; convergência em 3 iterações | `resultados/validacao_local/dois_grupos_np{1,2,4}.txt` |

A notação `{1,2,4}` representa três arquivos separados. Preencher o campo de commit com o hash da versão usada nos testes e registrar as versões do compilador e do MPI em `resultados/validacao_local/ambiente.txt`. O hash e essas versões ainda não foram informados neste documento.
