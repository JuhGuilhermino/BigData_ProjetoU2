"""EDA básica do Twitter Geospatial Data.

Uso (a partir de qualquer pasta):
    uv run src/EDA/eda.py                    # usa src/data/twitter.csv
    uv run src/EDA/eda.py arquivo.csv        # ou .zip
    uv run src/EDA/eda.py --amostra 500000   # só as N primeiras linhas

Imprime o relatório no terminal e salva os gráficos em src/EDA/saida/.
"""
import argparse
import json
import urllib.request
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # sem janela: roda em qualquer máquina
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LogNorm

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
SAIDA = AQUI / "saida"
GEOJSON = AQUI / "us-states.geojson"
URL_GEOJSON = "https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json"

# Caixa aproximada dos EUA continentais
LON_MIN, LON_MAX, LAT_MIN, LAT_MAX = -125.0, -66.0, 24.0, 50.0
FORA_DO_MAPA = {"Alaska", "Hawaii", "Puerto Rico"}


def ler_dados(caminho, amostra):
    return pd.read_csv(
        caminho,
        nrows=amostra,
        dtype={"longitude": "float64", "latitude": "float64", "timestamp": "int64", "timezone": "int8"},
    )


def relatorio(df, ts):
    print("== 1. Visão geral ==")
    print("linhas:", len(df))
    print("colunas:", list(df.columns))
    print("valores ausentes por coluna:\n", df.isna().sum().to_string())
    print("linhas duplicadas (iguais em tudo):", df.duplicated().sum())

    print("\n== 2. Estatísticas ==")
    print(df[["longitude", "latitude"]].describe().to_string())

    print("\n== 3. Coordenadas fora dos EUA continentais (aprox.) ==")
    fora = ~(df.latitude.between(LAT_MIN, LAT_MAX) & df.longitude.between(LON_MIN, LON_MAX))
    print("pontos fora da caixa:", fora.sum(), f"({fora.mean():.4%})")

    print("\n== 4. Timestamp ==")
    print("timestamps inválidos:", ts.isna().sum())
    print("primeiro:", ts.min(), "| último:", ts.max())

    print("\n== 5. Tweets por fuso ==")
    print(df.timezone.value_counts().sort_index().to_string())

    print("\n== 6. Tweets por dia ==")
    print(ts.dt.date.value_counts().sort_index().to_string())

    print("\n== 7. Dia x fuso (primeira pergunta da EDA) ==")
    print(pd.crosstab(ts.dt.date, df.timezone).to_string())

    print("\n== 8. Tweets por hora do dia (CST) ==")
    print(ts.dt.hour.value_counts().sort_index().to_string())


def obter_geojson():
    """Devolve a lista de estados, baixando o arquivo se ele não estiver no repo."""
    if not GEOJSON.exists():
        try:
            urllib.request.urlretrieve(URL_GEOJSON, GEOJSON)
        except OSError:
            print(f"Aviso: sem {GEOJSON.name} e sem internet; o mapa sai sem contornos.")
            return []
    with open(GEOJSON, encoding="utf-8") as f:
        return json.load(f)["features"]


def desenhar_estados(ax):
    estados = obter_geojson()
    for estado in estados:
        if estado["properties"]["name"] in FORA_DO_MAPA:
            continue
        geom = estado["geometry"]
        poligonos = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
        for poligono in poligonos:
            for anel in poligono:
                xs, ys = zip(*anel)
                ax.plot(xs, ys, color="white", linewidth=0.5, alpha=0.8)


def grafico_mapa(df):
    dentro = df[df.latitude.between(LAT_MIN, LAT_MAX) & df.longitude.between(LON_MIN, LON_MAX)]
    contagem, xe, ye = np.histogram2d(
        dentro.longitude, dentro.latitude, bins=[590, 260],
        range=[[LON_MIN, LON_MAX], [LAT_MIN, LAT_MAX]],
    )
    contagem = np.ma.masked_equal(contagem, 0)

    fig, ax = plt.subplots(figsize=(14, 8), facecolor="#111")
    ax.set_facecolor("#111")
    img = ax.imshow(
        contagem.T, origin="lower", extent=[LON_MIN, LON_MAX, LAT_MIN, LAT_MAX],
        cmap="inferno", norm=LogNorm(vmin=1, vmax=contagem.max()),
        aspect=1 / np.cos(np.radians(37)),
    )
    desenhar_estados(ax)
    ax.set_xlim(LON_MIN, LON_MAX)
    ax.set_ylim(LAT_MIN, LAT_MAX)
    ax.set_title(f"Densidade de tweets nos EUA continentais ({len(dentro):,} pontos)", color="white")
    ax.set_xlabel("longitude", color="white")
    ax.set_ylabel("latitude", color="white")
    ax.tick_params(colors="white")
    cbar = fig.colorbar(img, ax=ax, fraction=0.025, pad=0.01)
    cbar.set_label("tweets por célula (escala log)", color="white")
    cbar.ax.yaxis.set_tick_params(color="white")
    plt.setp(cbar.ax.get_yticklabels(), color="white")
    fig.tight_layout()
    return fig


def grafico_dia_fuso(df, ts):
    tabela = pd.crosstab(ts.dt.strftime("%d/%m"), df.timezone)
    tabela.columns = [{1: "Eastern", 2: "Central", 3: "Mountain", 4: "Pacific"}.get(c, str(c)) for c in tabela.columns]
    ax = tabela.plot(kind="bar", figsize=(10, 5), width=0.8)
    ax.set_title("Tweets por dia e fuso horário")
    ax.set_xlabel("dia (jan/2013)")
    ax.set_ylabel("tweets")
    ax.tick_params(axis="x", rotation=0)
    ax.legend(title="fuso")
    ax.figure.tight_layout()
    return ax.figure


def grafico_hora(ts):
    por_hora = ts.dt.hour.value_counts().sort_index()
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.plot(por_hora.index, por_hora.values, marker="o")
    ax.set_title("Tweets por hora do dia (CST)")
    ax.set_xlabel("hora")
    ax.set_ylabel("tweets")
    ax.set_xticks(range(0, 24, 2))
    ax.grid(alpha=0.3)
    fig.tight_layout()
    return fig


def main():
    pa = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    pa.add_argument("arquivo", nargs="?", default=RAIZ / "src" / "data" / "twitter.csv",
                    help=".csv ou .zip (padrão: src/data/twitter.csv)")
    pa.add_argument("--amostra", type=int, default=None, help="ler só as N primeiras linhas")
    args = pa.parse_args()

    if not Path(args.arquivo).exists():
        pa.error(f"arquivo não encontrado: {args.arquivo}")

    df = ler_dados(args.arquivo, args.amostra)
    ts = pd.to_datetime(df.timestamp.astype(str), format="%Y%m%d%H%M%S", errors="coerce")

    relatorio(df, ts)

    SAIDA.mkdir(exist_ok=True)
    for nome, fig in [
        ("mapa_eua.png", grafico_mapa(df)),
        ("dia_fuso.png", grafico_dia_fuso(df, ts)),
        ("tweets_por_hora.png", grafico_hora(ts)),
    ]:
        fig.savefig(SAIDA / nome, dpi=150, facecolor=fig.get_facecolor())
        plt.close(fig)
    print(f"\nGráficos salvos em {SAIDA}")


if __name__ == "__main__":
    main()
