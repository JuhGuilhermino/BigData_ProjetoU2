# Plano de testes — K-means com MPI

## Objetivo

A ideia é conferir primeiro se o programa agrupa os dados corretamente. Depois disso, medir o que muda no tempo de execução quando aumentamos o número de processos.

Esta etapa prepara os testes. Ainda não apresenta resultados de execução do MPI nem medições do NPAD.

## 1. Validação com dados pequenos

Vamos começar com dados sintéticos, pequenos o suficiente para calcular os resultados esperados à mão. Eles servem para testar o algoritmo, não representam tweets reais e não passam pelo pré-processamento.

| Caso | Configuração | O que conferir | Situação |
|---|---|---|---|
| Média dos pontos | 4 pontos e `k=1` | Todos no mesmo cluster; centroide igual à média | Preparado; execução pendente |
| Dimensão constante | 4 pontos, `k=1` e x constante | Sem NaN/infinito; x do centroide mantém o valor | Preparado; execução pendente |
| Dois grupos separados | 6 pontos e `k=2` | Dois grupos de 3 pontos e centroides esperados | Preparado; execução pendente |
| Variação dos processos | Repetir os casos com 1, 2 e 4 processos | Mesmo total de pontos e resultados compatíveis | Execução pendente |

Os comandos, arquivos de entrada e valores esperados serão mantidos em `tests/`. Não é necessário o dataset completo nem o NPAD para esses testes: basta uma máquina com MPI e compilador C++.

Critérios de aprovação:

- A execução termina sem erro e informa convergência.
- A soma dos tamanhos dos clusters é igual à quantidade de registros de entrada.
- Os centroides são compatíveis com os valores esperados.
- Mudar a quantidade de processos não causa perda ou duplicação de pontos.
- Não aparecem coordenadas NaN ou infinitas.

O programa imprime centroides com uma casa decimal. Na conferência manual, comparar com os valores esperados também arredondados para uma casa. Quando houver exportação com maior precisão, definir uma tolerância numérica explícita para a comparação automática.

Os números dos clusters são apenas identificadores. Dois resultados podem representar os mesmos grupos com os IDs trocados.

## 2. Próximos testes de correção

- Entradas inválidas: `k=0`, `k` maior que o número de pontos, arquivo inexistente e arquivo sem registros.
- Limite de iterações zero ou negativo: primeiro corrigir a validação, pois o código atual pode acessar um índice inválido.
- Limite de uma iteração: conferir se a saída informa que o limite foi atingido.
- Pontos repetidos e clusters vazios.
- Pré-processamento: linhas válidas/inválidas, contagem antes/depois e valores finitos após a projeção.
- Leitura distribuída: linhas de tamanhos diferentes, último registro sem quebra de linha e processos sem registros locais.

Esses casos ainda precisam ser implementados. Passar nos três casos iniciais não comprova que todas as entradas são tratadas corretamente.

## 3. Desempenho

Depois de validar a correção, executar o mesmo conjunto de dados com diferentes quantidades de processos.

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

- Casos pequenos com entradas, resultados esperados e evidências de execução.
- Medições brutas e logs de cada repetição.
- Tabela e gráficos de tempo, speedup e eficiência.
- Visualização de uma amostra dos pontos por cluster e distribuição temporal.
- Texto do relatório explicando ambiente, metodologia, resultados e limitações.

Para desenhar os clusters, ainda falta exportar os rótulos dos pontos e os centroides. A versão CUDA fica como experimento extra, depois da validação do MPI.

## 5. Registro de execução

Guardar os logs em uma pasta própria para cada rodada, por exemplo `resultados/local_<data>/` ou `resultados/npad_<job>/`.

| Data | Commit | Ambiente | Caso/configuração | Resultado observado | Log |
|---|---|---|---|---|---|
| — | — | — | — | Nenhuma execução MPI registrada nesta etapa | — |
