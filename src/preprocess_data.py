from pathlib import Path
import csv
import numpy as np
import pandas as pd
from pyproj import Transformer

INPUT, OUTPUT = Path("src/data/twitter.csv"), Path("src/data/twitter_processed.csv")
COLS = ["longitude", "latitude", "timestamp", "timezone"]
CHUNK = 100_000
transformer = Transformer.from_crs("EPSG:4326", "EPSG:5070", always_xy=True)


def timestamp_seconds(s):
    s = s.astype("string").str.strip()
    dt = pd.to_datetime(s, format="%Y%m%d%H%M%S", errors="coerce")
    return (dt - pd.Timestamp("1970-01-01")).dt.total_seconds()


def process(df):
    df.columns = df.columns.str.strip().str.lower()
    df = df.rename(columns={
        "lon": "longitude", "long": "longitude", "lat": "latitude",
        "time": "timestamp", "date": "timestamp",
        "date_time": "timestamp", "tz": "timezone", "time_zone": "timezone"
    })

    if not {"longitude", "latitude", "timestamp"} <= set(df.columns):
        raise ValueError(f"Colunas inválidas: {list(df.columns)}")

    if "timezone" not in df:
        df["timezone"] = np.nan

    df["longitude"] = pd.to_numeric(df["longitude"], errors="coerce")
    df["latitude"] = pd.to_numeric(df["latitude"], errors="coerce")
    df["timestamp_seconds"] = timestamp_seconds(df["timestamp"])

    valid = (
        df["longitude"].between(-180, 180)
        & df["latitude"].between(-90, 90)
        & df["timestamp_seconds"].notna()
    )
    df = df.loc[valid].copy()
    df["timestamp_seconds"] = df["timestamp_seconds"].astype("int64")

    df["x_m"], df["y_m"] = transformer.transform(
        df["longitude"].to_numpy(), df["latitude"].to_numpy()
    )
    return df[["x_m", "y_m", "timestamp_seconds", "timezone"]]


def main():
    if not INPUT.exists():
        raise FileNotFoundError(INPUT.resolve())

    with INPUT.open(encoding="utf-8-sig") as f:
        sample = f.read(8192)

    try:
        sep = csv.Sniffer().sniff(sample, delimiters=",;\t").delimiter
    except csv.Error:
        sep = r"\s+"

    first = sample.splitlines()[0]
    fields = first.split(sep) if sep != r"\s+" else first.split()
    header = {"longitude", "latitude", "timestamp"} <= {
        x.strip().lower() for x in fields
    }

    options = dict(
        sep=sep, chunksize=CHUNK, encoding="utf-8-sig",
        on_bad_lines="skip", header=0 if header else None
    )
    if not header:
        options["names"] = COLS

    total = 0
    for i, chunk in enumerate(pd.read_csv(INPUT, **options)):
        result = process(chunk)
        result.to_csv(OUTPUT, mode="w" if i == 0 else "a",
                      header=i == 0, index=False)
        total += len(result)
        print(f"Bloco {i + 1}: {len(result)} registros válidos")

    if total == 0:
        pd.DataFrame(columns=[
            "x_m", "y_m", "timestamp_seconds", "timezone"
        ]).to_csv(OUTPUT, index=False)

    print(f"Total: {total} registros. Arquivo: {OUTPUT.resolve()}")


if __name__ == "__main__":
    main()




