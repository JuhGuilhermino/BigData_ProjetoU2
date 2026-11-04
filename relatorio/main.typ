#let incluir-amostra-mpi = true

#import "@preview/charged-ieee:0.1.4": ieee

#show: ieee.with(
  title: [Projeto da 2ª Unidade - Implementação do K-means Utilizando MPI],
  abstract: [
    Este trabalho apresenta uma implementação de K-means em C++ com MPI
    aplicada ao Twitter Geospatial Data, com 14.262.517 registros. O agrupamento
    considera posição projetada e tempo, com normalização min-max. A leitura
    e a atribuição dos pontos são distribuídas entre processos, enquanto
    operações coletivas combinam as estatísticas de cada grupo. Três casos
    sintéticos foram validados com 1, 2 e 4 processos, com resultados
    compatíveis com os valores esperados nas nove execuções. No experimento
    com o dataset completo, o tempo mediano do K-means caiu de 40,96 s com
    um processo para 6,87 s com 16 processos, correspondendo a speedup de
    5,96 e eficiência de aproximadamente 37%. A versão complementar CUDA
    apresentou 4,95 s na etapa de K-means. Os resultados indicam ganhos de
    desempenho no equipamento avaliado, com redução da eficiência nas
    maiores configurações.
  ],
  authors: (
    (
      name: "Flávio",
      department: [Graduando em Ciência da Computação],
      organization: [DIMAp - UFRN],
      location: [Natal, Brasil],
      email: "flavio.oliveira.124@ufrn.edu.br",
    ),
    (
      name: "Júlia Maria Azevedo Guilhermino",
      department: [Graduanda em Ciência da Computação],
      organization: [DIMAp - UFRN],
      location: [Natal, Brasil],
      email: "juh.guilhermino03@gmail.com",
    ),
    (
      name: "Thiago Lopes Martins",
      department: [Graduando em Ciência da Computação],
      organization: [DIMAp - UFRN],
      location: [Natal, Brasil],
      email: "thiago_lopes7@outlook.com",
    ),
    (
      name: "Kauã do Vale Ferreira",
      department: [Graduando em Ciência da Computação],
      organization: [DIMAp - UFRN],
      location: [Natal, Brasil],
      email: "kaua.vale.632@ufrn.edu.br",
    ),
  ),
  index-terms: ("K-means", "MPI", "Programação Paralela", "Clustering espaço-temporal"),
  bibliography: bibliography("refs.bib"),
  figure-supplement: [Fig.],
)

#set text(lang: "pt")
#set par(leading: 0.4em, spacing: 0.4em)
#show raw.where(block: true): set text(size: 7.5pt)
#set table(inset: (x: 4pt, y: 4pt))

= Introdução

Este relatório apresenta a arquitetura, os resultados e a análise de
desempenho de uma implementação paralela do algoritmo de clusterização
K-means, desenvolvida para a disciplina de Sistemas Big Data. O estudo
utiliza o Twitter Geospatial Data, composto por 14.262.517 tweets
geolocalizados nos Estados Unidos, coletados entre 12 e 18 de janeiro
de 2013 @twitter. O objetivo é agrupar os registros considerando a posição
espacial e a dimensão temporal, além de avaliar o efeito do número de
processos sobre o tempo de execução.

A implementação principal foi escrita em C++ e paralelizada com MPI
(*Message Passing Interface*), permitindo distribuir os dados e o cálculo
entre processos. O projeto inclui uma implementação complementar em CUDA
e scripts Python para pré-processamento, análise exploratória e geração
das tabelas e dos gráficos. Os testes de desempenho foram executados
em um único notebook, com diferentes quantidades de processos MPI.
Não foram realizados testes entre múltiplos nós.

O pré-processamento converte longitude e latitude para metros em EPSG:5070
e transforma o timestamp em segundos relativos à referência 1970-01-01,
mantendo a base temporal comum dos registros. Os horários originais estão
em CST @twitter. O atributo timezone permanece no CSV processado, mas não
entra no agrupamento. As três dimensões utilizadas são x, y e tempo,
normalizadas para o intervalo $[0, 1]$. Elas entram na distância sem pesos
adicionais; igualar as amplitudes não garante influência estatística
idêntica sobre os grupos.

A análise exploratória inclui a distribuição espacial apresentada na
@fig:mapa-eda. Esse mapa contextualiza a localização dos registros;
as atribuições aos clusters são apresentadas separadamente na
visualização produzida pela execução MPI.

#figure(
  image("figuras/mapa_eua.png", width: 100%),
  caption: [Distribuição espacial dos tweets apresentada na análise exploratória.],
  placement: none,
) <fig:mapa-eda>

= Implementação

== Leitura distribuída e normalização

Para lidar com os registros, adotou-se leitura paralela do dataset. Cada
processo acessa o arquivo CSV e extrai a sua porção de dados, sem um
processo central carregar e distribuir todo o conjunto. A divisão utiliza
o tamanho do arquivo e o identificador de cada processo:

#figure(
  image("figuras/Código CLP.png", width: 100%),
  caption: [Particionamento do arquivo entre os processos MPI.],
  placement: none,
) <fig:codigo-particao>

Como uma fronteira pode cortar uma linha, a função `readData` usa
`seekg` e `std::getline` para ajustar o início da leitura. O critério de
particionamento é atribuir cada registro à faixa em que sua linha começa.
Os testes específicos para todos os casos extremos dessa leitura ainda
precisam ser ampliados.

Os dados locais são armazenados em um `std::vector<Tweet>`. Cada processo
calcula seus mínimos e máximos, e a função `computeRange` utiliza
`MPI_Allreduce` para obter os limites globais:

#figure(
  image("figuras/Codigo CR.png", width: 100%),
  caption: [Reduções para obter os limites globais das dimensões.],
  placement: none,
) <fig:codigo-limites>

Com os limites globais, cada processo normaliza seus próprios registros.
Uma dimensão constante utiliza denominador 1, evitando divisão por zero.
As reduções coletivas fazem parte do modelo de comunicação definido pelo
padrão MPI @mpi.

== Inicialização dos centroides

O K-means escolhe k índices globais distintos com `std::mt19937_64`, usando
a semente informada na execução. As contagens locais e `MPI_Exscan`
permitem identificar a posição de cada partição na sequência global dos
registros. Apenas o processo que possui o ponto sorteado preenche suas
coordenadas no buffer; os demais contribuem com zero. Uma redução por soma
disponibiliza os centroides iniciais a todos:

#figure(
  image("figuras/Codigo IC.png", width: 100%),
  caption: [Distribuição dos centroides iniciais por redução coletiva.],
  placement: none,
) <fig:codigo-inicializacao>

Esse procedimento mantém os pontos iniciais para o mesmo arquivo e a
mesma semente. Entretanto, a ordem das somas em ponto flutuante pode mudar
com o número de processos, de modo que não se garante o mesmo percurso
numérico para qualquer configuração.

== Atribuição, atualização e convergência

Em cada iteração, cada processo percorre seus pontos, calcula a distância
euclidiana ao quadrado até os centroides e atribui cada ponto ao grupo
mais próximo. Essa etapa é local. Depois, a redução abaixo verifica se
alguma atribuição foi alterada:

#figure(
  image("figuras/Codigo AC.png", width: 100%),
  caption: [Verificação global de alterações nas atribuições.],
  placement: none,
) <fig:codigo-convergencia>

Quando nenhuma atribuição muda, o algoritmo informa convergência e
encerra. Caso contrário, são calculadas somas e contagens locais por
grupo. Duas chamadas adicionais combinam essas estatísticas:

#figure(
  image("figuras/Codigo centroids.png", width: 100%),
  caption: [Reduções das somas e contagens para atualizar os centroides.],
  placement: none,
) <fig:codigo-centroides>

Cada centroide é atualizado pela divisão entre soma global e contagem
global. Clusters vazios mantêm a posição anterior. Uma iteração com
atualização utiliza, portanto, três chamadas a `MPI_Allreduce`; a iteração
que detecta convergência termina antes das duas reduções por soma. As
mensagens dependem do número de clusters e dimensões, mas a latência e a
sincronização das operações coletivas ainda podem limitar a escalabilidade.

== Versão CUDA e instrumentação

A versão CUDA utiliza um kernel para atribuir os pontos e acumular
estatísticas, com memória compartilhada e operações atômicas. As somas e
contagens retornam à CPU, que atualiza os centroides a cada iteração. O
modelo de programação CUDA é descrito pela NVIDIA @cuda.

O tempo MPI reportado é o maior entre os processos, e a leitura inclui
a normalização. O intervalo do K-means MPI inclui a inicialização dos
centroides. Na CUDA, essa inicialização ocorre antes do cronômetro do
K-means; o intervalo cronometrado inclui as transferências das estatísticas
por iteração e as atualizações na CPU. A transferência inicial dos dados
para a GPU é medida à parte. Essas diferenças devem ser consideradas ao
comparar as duas implementações.

= Testes e metodologia

== Validação com dados sintéticos

Foram preparados três casos pequenos com resultados esperados calculáveis
manualmente: média de quatro pontos, dimensão constante e dois grupos
separados. Cada caso foi executado com 1, 2 e 4 processos, semente 42 e
limite de 100 iterações, totalizando nove execuções. As contagens,
centroides impressos e iterações coincidiram entre as configurações.

#figure(
  table(
    columns: (1.5fr, 0.6fr, 0.5fr, 1fr),
    table.header[ Caso ][ Pontos ][ k ][ Iterações ],
    [Média], [4], [1], [2],
    [Dimensão constante], [4], [1], [2],
    [Dois grupos], [6], [2], [3],
  ),
  caption: [Validação sintética: resultados iguais com 1, 2 e 4 processos.],
  placement: none,
) <tab:validacao>

O caso de média apresentou centroide (3,0; 6,0; 1,5), e o de dimensão
constante apresentou (10,0; 5,0; 1,5). No caso de dois grupos, foram obtidos
três pontos em cada grupo, com centroides (0,7; 0,7; 0,0) e
(100,7; 100,7; 10,0). Nessas coordenadas, x e y estão em metros, e o tempo
em horas após o início. Todas as execuções informaram convergência e não
apresentaram coordenadas NaN ou infinitas na saída.

A comparação respeitou uma casa decimal, precisão impressa pelo programa.
Os logs estão em `resultados/validacao_local/`, referentes ao commit
`2031139`, com Open MPI 4.1.2 e g++ 11.4.0. Esses testes são evidência para
os casos avaliados, sem demonstrar correção para toda entrada. Os tempos
impressos como 0.000 s não foram usados para avaliar desempenho.

A exportação foi verificada por cinco testes automatizados, executados
com sucesso no notebook de Kauã. Eles cobrem execuções com e sem
exportação, limite e repetibilidade da amostra, proteção contra
sobrescrita, processos sem pontos locais e rejeição da visualização
quando a execução não converge.

== Experimento de desempenho

O ambiente e os parâmetros utilizados estão na @tab:ambiente. Foram
registradas três repetições para cada uma das cinco configurações MPI e
três execuções CUDA, totalizando 18 medições no arquivo `medicoes.csv`.
O limite de 300 iterações é um teto: o algoritmo pode convergir antes.

#figure(
  table(
    columns: (0.9fr, 2fr),
    table.header[ Item ][ Configuração ],
    [CPU], [Intel Core i5-13450HX; 6 P-cores + 4 E-cores; 16 threads],
    [GPU], [RTX 4050 Laptop; 5772 MB],
    [Dataset], [14.262.517 tweets],
    [Parâmetros], [k = 8; semente 42; limite 300],
    [Processos], [1, 2, 4, 8 e 16],
    [Repetições], [3 por configuração],
    [Data], [03/11/2026],
  ),
  caption: [Ambiente e parâmetros do experimento de desempenho.],
  placement: none,
) <tab:ambiente>

O processador possui dez núcleos físicos e 16 threads. Na configuração
com 16 processos, há compartilhamento de núcleos físicos. A estatística adotada neste relatório
é a mediana. O speedup e a eficiência MPI são calculados pelas expressões
abaixo, usando a própria implementação MPI com um processo como referência.

$ S(p) = T(1) / T(p) quad E(p) = S(p) / p $

O total considerado é leitura mais K-means, somados em cada repetição
antes de calcular a mediana. Assim, ele pode diferir da soma das medianas
das etapas. Não representa toda a pipeline nem inclui a transferência
inicial para a GPU. O resumo CPU do repositório usa médias; a análise
comparativa aqui utiliza as medianas do CSV.

= Resultados e discussão

== Desempenho

Os tempos e as métricas estão na @tab:desempenho. O tempo mediano do
K-means diminuiu de 40,96 s com um processo para 6,87 s com 16 processos.
Até quatro processos, o ganho aproximou-se do crescimento proporcional,
com speedup de 3,73 e eficiência de 93%. Com oito e 16 processos, os
tempos continuaram caindo, mas os ganhos adicionais foram menores.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr, 1.3fr, 1fr, 1.2fr),
    table.header[Configuração][Leitura (s)][K-means (s)][Total (s)][Speedup K-means][Eficiência MPI][Speedup total],
    [MPI 1], [3.89], [40.96], [44.87], [1.00], [100%], [1.00],
    [MPI 2], [1.90], [21.28], [23.22], [1.92], [96%], [1.93],
    [MPI 4], [1.00], [10.98], [11.99], [3.73], [93%], [3.74],
    [MPI 8], [0.72], [8.35], [9.06], [4.90], [61%], [4.95],
    [MPI 16], [0.46], [6.87], [7.33], [5.96], [37%], [6.12],
    [CUDA], [3.84], [4.95], [8.79], [8.28], [-], [5.10],
  ),
  caption: [Medianas de três repetições. Total = leitura + K-means, sem a cópia inicial para a GPU. Fonte: medicoes.csv.],
  scope: "parent",
  placement: top,
) <tab:desempenho>

#figure(
  image("figuras/tempos.png", width: 100%, height: 155pt, fit: "contain"),
  caption: [Tempos medianos por configuração. As barras representam métricas distintas, não parcelas a somar.],
  scope: "parent",
  placement: top,
) <fig:tempos>

O processador combina núcleos de desempenhos diferentes e, com 16
processos, utiliza threads em núcleos compartilhados. Essa característica,
assim como os custos das operações coletivas, pode contribuir para a
redução da eficiência observada na @fig:desempenho. As medições não
isolam esses fatores, que permanecem hipóteses explicativas.

#figure(
  image("figuras/desempenho.png", width: 100%, height: 145pt, fit: "contain"),
  caption: [Speedup e eficiência MPI, tendo um processo como referência.],
  scope: "parent",
  placement: top,
) <fig:desempenho>

A GPU apresentou 4,95 s na etapa de K-means, correspondendo a speedup
de 8,28 em relação ao MPI com um processo. Entretanto, a soma medida de
leitura e K-means foi menor no MPI com 16 processos: 7,33 s contra
8,79 s na CUDA. A vantagem no cálculo não implica menor tempo de todas
as etapas consideradas. A comparação também está sujeita às diferenças
de instrumentação descritas na implementação.

A convergência foi verificada na execução complementar com dois processos
MPI, encerrada na iteração 262. O arquivo `medicoes.csv` registra os
tempos das repetições do benchmark, mas não armazena o número de iterações
de cada execução.

As tabelas e os gráficos de desempenho foram calculados a partir de
`medicoes.csv`. Os três tempos CUDA de `resultados_gpu.md` diferem dos
registros do CSV e não foram combinados com eles. A origem dessa diferença
ainda precisa ser esclarecida.

== Resultados de clustering

Uma execução complementar no notebook de Kauã utilizou dois processos MPI,
k = 8, semente 42 e limite de 300 iterações. Foram processados 14.262.517
registros, com convergência na iteração 262. As contagens e os centroides
impressos coincidiram com os resultados CUDA registrados em `resultados_gpu.md`, na precisão
exibida.
Essa comparação não comprova igualdade de todas as atribuições individuais.

A execução registrou 10,221 s na leitura e 23,424 s no K-means e foi
utilizada para exportar os rótulos e produzir a visualização. Esses tempos
não integram as repetições da tabela de desempenho, realizadas em outro
equipamento. O log está em `resultados/visualizacao_mpi_execucao.txt`.

A @tab:clusters apresenta os tamanhos dos oito clusters e os tempos dos
centroides, confirmados nessa execução MPI. As contagens somam 14.262.517
tweets. Os identificadores são apenas rótulos, e o tempo do centroide
representa uma média temporal, não a duração do grupo.

#figure(
  table(
    columns: (0.6fr, 1.2fr, 1fr),
    table.header[Cluster][Tweets][t (h)],
    [0], [2.306.017], [28.6],
    [1], [2.407.688], [82.2],
    [2], [1.436.137], [28.8],
    [3], [1.195.896], [41.2],
    [4], [2.570.519], [139.4],
    [5], [1.262.018], [125.9],
    [6], [1.457.948], [82.0],
    [7], [1.626.294], [139.1],
  ),
  caption: [Contagens e tempos dos centroides confirmados na execução complementar MPI.],
  placement: none,
) <tab:clusters>

#figure(
  image("figuras/centroides_espaciais.png", width: 100%, height: 155pt, fit: "contain"),
  caption: [Centroides da execução CUDA em EPSG:5070. A área dos círculos é proporcional à contagem; as anotações indicam ID e tempo. Centros próximos podem se sobrepor.],
  scope: "parent",
  placement: top,
) <fig:centroides>

Os centroides dos IDs 0, 1 e 4; 2, 6 e 7; e 3 e 5 ocupam três regiões
aproximadas do plano projetado, com separação temporal dentro desses
conjuntos (@fig:centroides). Isso é compatível com o uso conjunto de
posição e tempo. Entretanto, a figura mostra centros e contagens, sem
revelar fronteiras ou dispersão interna dos grupos. Não permite concluir
que os clusters correspondem a cidades ou que k = 8 é a escolha ótima.

#if incluir-amostra-mpi [
  #figure(
    image("figuras/clusters_amostra.png", width: 100%),
    caption: [Amostra de pontos com rótulos exportados pelo MPI, nos planos espacial e espaço-temporal. As barras apresentam as contagens do conjunto completo.],
    scope: "parent",
    placement: top,
  ) <fig:amostra>

  A @fig:amostra apresenta os rótulos efetivamente calculados pelo MPI.
  Foram exportados até 10.000 pontos por processo, com amostragem uniforme
  dentro de cada partição. Essa amostra não deve ser interpretada como
  estimativa de densidade global. Nesta execução, as contagens e os
  centroides impressos foram comparados aos resultados CUDA registrados
  em `resultados_gpu.md`. A visualização
  utiliza os rótulos exportados pela execução MPI complementar.
] else [
  *Pendência desta versão:* a amostra dos pontos com seus rótulos MPI ainda
  precisa ser executada sobre o dataset completo e incorporada ao relatório.
  Os centroides acima não substituem a apresentação das atribuições dos
  pontos. O código de exportação e o script de visualização já estão
  disponíveis no projeto.
]

== Limitações

O benchmark contém três repetições por configuração em um único
equipamento. Não permite generalizar os resultados para outros
processadores ou múltiplos nós. Não foram registrados, para as execuções originais do benchmark,
o commit do código, o hash do arquivo de entrada, as versões do
compilador e do MPI nem os logs completos de cada repetição. Os registros
da validação sintética e da execução complementar correspondem a
experimentos distintos.

A validação de entradas inválidas, casos extremos de leitura e clusters
vazios precisa ser ampliada. Também não foram avaliados outros valores de
k ou métricas como silhueta. Normalizar os atributos reduz a dependência
das unidades, mas não prova separação adequada dos grupos nem qualidade
ótima do agrupamento.

= Conclusão

O trabalho implementou K-means com MPI, distribuindo a leitura, a
normalização e a atribuição dos pontos e consolidando as estatísticas
por reduções coletivas. Nos três conjuntos sintéticos avaliados, as
contagens e os centroides impressos foram compatíveis com os resultados
esperados para 1, 2 e 4 processos, fornecendo evidência de consistência
para esses casos.

Nos testes de desempenho, o aumento de processos reduziu o tempo mediano
do K-means de 40,96 s para 6,87 s. O speedup de 5,96 com 16 processos
mostra ganho de desempenho, acompanhado de eficiência de 37%. A maior
aproximação ao ganho proporcional ocorreu até quatro processos. A CUDA
apresentou menor tempo de cálculo, enquanto a soma medida de leitura e
K-means favoreceu o MPI com 16 processos, nas condições documentadas.

A execução complementar MPI confirmou convergência em 262 iterações
e permitiu visualizar uma amostra dos pontos com seus rótulos. Os
centroides e as contagens indicam estrutura espacial e temporal, sem
demonstrar que o agrupamento é ótimo. Os testes sintéticos verificaram os resultados esperados nos casos
avaliados, e o benchmark mostrou a redução do tempo com o aumento de
processos. Como trabalhos futuros, propõem-se ampliar os casos de teste,
registrar o ambiente completo de cada execução, alinhar os intervalos
medidos entre CPU e GPU e comparar outros valores de k.
