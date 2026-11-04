# Plano de testes — K-means com MPI

## Objetivo

A ideia é conferir primeiro se o programa agrupa os dados corretamente. Depois disso, medir o que muda no tempo de execução quando aumentamos o número de processos.

A validação inicial com dados sintéticos foi concluída localmente em 29/10/2026. Os três casos foram executados com 1, 2 e 4 processos e tiveram os resultados conferidos manualmente. As medições de desempenho também foram incorporadas: 15 execuções MPI e 3 CUDA, com tabela e gráficos gerados a partir de `resultados/medicoes.csv`. Os testes adicionais continuam pendentes. O ambiente documentado para as medições é um notebook; não há evidência de execução no NPAD nos arquivos disponíveis.

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

As medições fornecidas por Flávio estão em [medicoes.csv](../resultados/medicoes.csv). O arquivo contém 18 registros: três repetições para cada uma das cinco configurações MPI e três para CUDA. Os resumos de execução estão em [resultados_cpu.md](../resultados/resultados_cpu.md) e [resultados_gpu.md](../resultados/resultados_gpu.md).

| Parâmetro | Experimento registrado |
|---|---|
| Data informada nos resumos | 03/11/2026 |
| CPU | Intel Core i5-13450HX, 6 P-cores + 4 E-cores, 16 threads |
| GPU | NVIDIA GeForce RTX 4050 Laptop GPU, 5772 MB |
| Dados informados | `src/data/twitter_processed.csv`, 14.262.517 tweets |
| Atributos | x, y e tempo, com normalização min-max |
| Clusters | `k=8` |
| Semente | `42` |
| Processos MPI | `1, 2, 4, 8, 16` |
| Repetições | 3 por configuração, substituindo a proposta inicial de 5 |
| Limite de iterações | 300 |
| Afinidade informada | `--bind-to core` até 10 processos; `--use-hwthread-cpus` para 16 |
| Referência do speedup | Implementação MPI com 1 processo |
| Estatística da tabela gerada | Mediana das três repetições |

### Cálculos e reprodução

O script `src/desempenho.py` gera [desempenho.md](../resultados/desempenho.md) e [desempenho.png](../resultados/desempenho.png). A tabela apresenta tempos, speedup e eficiência; os gráficos apresentam speedup e eficiência do MPI.

Com o ambiente virtual já preparado, executar na raiz do projeto:

```bash
.venv/bin/python src/desempenho.py
```

Essa etapa reprocessa o CSV existente, sem executar novamente o K-means. Também é possível usar `uv run src/desempenho.py` quando `uv` estiver instalado.

O speedup é calculado como `T1 / Tp`; a eficiência MPI, como `speedup / p`. As colunas de leitura e de K-means usam suas respectivas medianas. Para o total, primeiro somamos leitura e K-means de cada repetição e depois calculamos a mediana dessas somas. Por isso o total pode diferir da soma das duas medianas exibidas.

O total apresentado inclui apenas leitura + K-means. Não representa todo o tempo da pipeline e, na GPU, não inclui a cópia dos dados para a placa. O tempo de leitura do MPI inclui a normalização.

O arquivo `resultados_cpu.md` apresenta médias; a tabela gerada apresenta medianas. Essas estatísticas devem ser identificadas e não misturadas na discussão. Para a comparação MPI/CUDA da tabela, a fonte comum é `medicoes.csv`. Os tempos de GPU em `resultados_gpu.md` diferem dos registros CUDA desse CSV; preservar ambos e confirmar a origem antes de tratá-los como as mesmas repetições.

### Convergência e rastreabilidade

Os resumos fornecidos informam convergência na iteração 262. O CSV registra apenas processos, repetição e tempos: não permite verificar, por si só, convergência, centroides ou contagens. As saídas completas das repetições de desempenho não estão disponíveis nesta entrega.

Para completar a rastreabilidade, ainda faltam o commit efetivamente usado no benchmark, o hash SHA-256 do arquivo de entrada, as versões do compilador/MPI do ambiente medido e os logs completos. O commit e as versões registrados na validação sintética não devem ser atribuídos automaticamente ao benchmark.

Uma execução no NPAD permanece como possibilidade futura, dependente de configuração e registro do ambiente. Os números atuais devem ser apresentados como medições no notebook informado.

## 4. Entregas da parte de testes

- [x] Três casos pequenos com entradas, resultados esperados e nove logs de execução local.
- [x] Medições brutas de desempenho: 15 MPI e 3 CUDA em `medicoes.csv`.
- [x] Tabela com tempos, speedup e eficiência; gráficos de speedup e eficiência MPI.
- [ ] Testes adicionais de correção, incluindo entradas inválidas e leitura distribuída.
- [ ] Logs completos e metadados restantes das repetições de desempenho.
- [ ] Visualização de uma amostra dos pontos por cluster e distribuição temporal.
- [ ] Integração e revisão final da seção de testes e resultados no relatório do grupo.

Os centroides e as contagens da GPU estão documentados, mas não há exportação dos rótulos de cada ponto. Para visualizar uma amostra colorida por cluster, ainda falta essa exportação. A versão CUDA já possui medições como experimento complementar; isso não substitui uma validação completa da implementação GPU.

## 5. Registro de execução

Os logs desta rodada foram salvos em `resultados/validacao_local/`. Cada configuração tem uma execução registrada. Nas próximas rodadas, usar pastas diferentes, por exemplo `resultados/local_<data>/` ou `resultados/npad_<job>/`, para preservar as evidências anteriores.

| Data | Commit | Ambiente | Caso/configuração | Resultado observado | Log |
|---|---|---|---|---|---|
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Média; k=1; np=1, 2 e 4 | Aprovado; 4 pontos; convergência em 2 iterações | `resultados/validacao_local/media_np{1,2,4}.txt` |
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Dimensão constante; k=1; np=1, 2 e 4 | Aprovado; 4 pontos; convergência em 2 iterações | `resultados/validacao_local/dimensao_constante_np{1,2,4}.txt` |
| 29/10/2026 | 20311394b802c6f9a76021149ec4e8c869851c2a | Local | Dois grupos; k=2; np=1, 2 e 4 | Aprovado; 3 pontos por cluster; convergência em 3 iterações | `resultados/validacao_local/dois_grupos_np{1,2,4}.txt` |

A notação `{1,2,4}` representa três arquivos separados. O hash acima identifica a versão usada na validação sintética. As versões registradas em `resultados/validacao_local/ambiente.txt` são Open MPI 4.1.2 e g++ 11.4.0 (Ubuntu). Criar novos commits de documentação não altera esse registro histórico.

As medições de desempenho de 03/11/2026 estão em `resultados/medicoes.csv`; o commit usado nessas medições ainda precisa ser confirmado. Não confundir o commit que adicionou os resultados ao Git com o commit do código que foi executado.
