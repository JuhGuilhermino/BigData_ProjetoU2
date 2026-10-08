# Twitter Geospatial Data 

## O que é?
Conjunto de dados da UCI com **14.262.517 tweets geolocalizados**, publicados
entre **12 e 18/01/2013** nos Estados Unidos.

Não temos o texto dos tweets: só **onde** e **quando** cada um foi publicado.

## Como os dados estão organizados
Um CSV , uma linha por tweet, 4 colunas:

| Coluna      | O que é                          | Exemplo        |
|-------------|----------------------------------|----------------|
| `longitude` | Posição geográfica               | -87.89544989   |
| `latitude`  | Posição geográfica               | 43.0630071     |
| `timestamp` | Data e hora (AAAAMMDDhhmmss)     | 20130112000000 |
| `timezone`  | Fuso: 1 Eastern, 2 Central, 3 Mountain, 4 Pacific | 2 |

- Tamanho: ~180 MB compactado, ~587 MB descompactado.
- Sem valores ausentes.
- Horários registrados em CST.
- `timezone` é uma **categoria**.

## O que vamos fazer
Implementar o **K-means com MPI**, agrupar os tweets e comparar o
desempenho com diferentes quantidades de processos.

## Cuidados antes de rodar o K-means
1. **Timestamp:** converter data/hora em um único valor em segundos
2. **Normalização:** longitude, latitude e tempo têm escalas muito diferentes.
3. **Interpretação:** clusters são os grupos de *tweets*.

## Próximos passos
1. Entender os dados 
2. EDA (distribuição, valores estranhos, duplicados, geografia)
3. Preparar atributos e normalizar
4. Implementar K-means com MPI
5. Testes de desempenho e visualização dos clusters

**Primeira pergunta da EDA:** como os tweets se distribuem entre os
7 dias e os 4 fusos horários?

Fonte: https://archive.ics.uci.edu/dataset/1050/twitter+geospatial+data