import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
RESULTADOS = RAIZ / "resultados"


def main():
    pa = argparse.ArgumentParser(description="Gera tabela e gráficos de speedup e eficiência a partir de resultados/medicoes.csv.")
    pa.add_argument("--medicoes", default=RESULTADOS / "medicoes.csv")
    args = pa.parse_args()

    df = pd.read_csv(args.medicoes, dtype={"processos": "string"})
    df["total_s"] = df["leitura_s"] + df["kmeans_s"]
    mediana = df.groupby("processos")[["leitura_s", "kmeans_s", "total_s"]].median()

    gpu = mediana.loc["gpu"] if "gpu" in mediana.index else None
    mpi = mediana.drop(index="gpu", errors="ignore")
    mpi.index = mpi.index.astype(int)
    mpi = mpi.sort_index()
    if 1 not in mpi.index:
        pa.error("as medições precisam incluir 1 processo (linha de base)")

    base = mpi.loc[1]
    speedup = base / mpi
    eficiencia = speedup.div(mpi.index, axis=0)

    linhas = [
        "| Processos | Leitura (s) | K-means (s) | Total (s) | Speedup K-means | Eficiência K-means | Speedup total |",
        "|---|---|---|---|---|---|---|",
    ]
    for p in mpi.index:
        linhas.append(
            f"| {p} | {mpi.loc[p, 'leitura_s']:.2f} | {mpi.loc[p, 'kmeans_s']:.2f} | {mpi.loc[p, 'total_s']:.2f} "
            f"| {speedup.loc[p, 'kmeans_s']:.2f}x | {eficiencia.loc[p, 'kmeans_s']:.0%} | {speedup.loc[p, 'total_s']:.2f}x |"
        )
    if gpu is not None:
        linhas.append(
            f"| GPU | {gpu['leitura_s']:.2f} | {gpu['kmeans_s']:.2f} | {gpu['total_s']:.2f} "
            f"| {base['kmeans_s'] / gpu['kmeans_s']:.2f}x | - | {base['total_s'] / gpu['total_s']:.2f}x |"
        )
    tabela = "\n".join(linhas)
    print(tabela)

    RESULTADOS.mkdir(exist_ok=True)
    (RESULTADOS / "desempenho.md").write_text(tabela + "\n", encoding="utf-8")

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5))
    ax1.plot(mpi.index, mpi.index, "--", color="gray", label="ideal")
    ax1.plot(mpi.index, speedup["kmeans_s"], marker="o", label="K-means")
    ax1.plot(mpi.index, speedup["total_s"], marker="s", label="leitura + K-means")
    ax1.set_xlabel("processos")
    ax1.set_ylabel("speedup")
    ax1.set_title("Speedup")
    ax1.set_xticks(mpi.index)
    ax1.legend()
    ax1.grid(alpha=0.3)

    ax2.plot(mpi.index, eficiencia["kmeans_s"] * 100, marker="o", label="K-means")
    ax2.plot(mpi.index, eficiencia["total_s"] * 100, marker="s", label="leitura + K-means")
    ax2.axhline(100, linestyle="--", color="gray")
    ax2.set_xlabel("processos")
    ax2.set_ylabel("eficiência (%)")
    ax2.set_title("Eficiência")
    ax2.set_xticks(mpi.index)
    ax2.legend()
    ax2.grid(alpha=0.3)

    fig.tight_layout()
    fig.savefig(RESULTADOS / "desempenho.png", dpi=150)
    print(f"\nSalvo em {RESULTADOS}")


if __name__ == "__main__":
    main()
