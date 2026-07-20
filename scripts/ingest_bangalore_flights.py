"""
Polls the OpenSky Network live API for aircraft currently in Bangalore
airspace and appends each poll as timestamped rows into Snowflake.

OpenSky's /states/all endpoint is free and requires no auth for
anonymous/basic use, but is rate-limited (~1 request per 10s recommended
for anonymous users).

Run: python scripts/ingest_bangalore_flights.py --polls 30 --interval 15
"""

import argparse
import time
from datetime import datetime, timezone

import pandas as pd
import requests
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import os

# Bounding box roughly covering Bangalore + Kempegowda Intl Airport airspace
LAMIN, LAMAX = 12.75, 13.25
LOMIN, LOMAX = 77.35, 77.85

OPEN_SKY_URL = "https://opensky-network.org/api/states/all"

COLUMNS = [
    "ICAO24", "CALLSIGN", "ORIGIN_COUNTRY", "TIME_POSITION", "LAST_CONTACT",
    "LONGITUDE", "LATITUDE", "BARO_ALTITUDE", "ON_GROUND", "VELOCITY",
    "TRUE_TRACK", "VERTICAL_RATE", "SENSORS", "GEO_ALTITUDE", "SQUAWK",
    "SPI", "POSITION_SOURCE", "CATEGORY",
]

def fetch_bangalore_states():
    params = {"lamin": LAMIN, "lomin": LOMIN, "lamax": LAMAX, "lomax": LOMAX}
    resp = requests.get(OPEN_SKY_URL, params=params, timeout=15)
    resp.raise_for_status()
    data = resp.json()

    states = data.get("states") or []
    polled_at = datetime.now(timezone.utc).isoformat()

    rows = []
    for s in states:
        # OpenSky returns fixed-position arrays per state, pad in case of length drift
        s = (s + [None] * len(COLUMNS))[:len(COLUMNS)]
        row = dict(zip(COLUMNS, s))
        row["POLLED_AT"] = polled_at
        rows.append(row)

    return pd.DataFrame(rows)

def load_to_snowflake(df: pd.DataFrame):
    if df.empty:
        print("No aircraft currently in bounding box this poll -- skipping write.")
        return

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role="DBT_TRANSFORMER",
        warehouse="TRIP_ANALYTICS_WH",
        database="TRIP_ANALYTICS",
        schema="STAGING",
    )

    success, nchunks, nrows, _ = write_pandas(
        conn,
        df,
        table_name="RAW_BANGALORE_FLIGHTS",
        auto_create_table=True,
        overwrite=False,  # append, since each poll is a new time-series slice
    )
    print(f"Appended {nrows} rows to TRIP_ANALYTICS.STAGING.RAW_BANGALORE_FLIGHTS")
    conn.close()

def main(polls: int, interval: int):
    for i in range(polls):
        print(f"Poll {i + 1}/{polls}...")
        try:
            df = fetch_bangalore_states()
            load_to_snowflake(df)
        except requests.exceptions.RequestException as e:
            print(f"Request failed: {e} -- skipping this poll.")
        if i < polls - 1:
            time.sleep(interval)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--polls", type=int, default=30, help="number of polls to run")
    parser.add_argument("--interval", type=int, default=15, help="seconds between polls")
    args = parser.parse_args()
    main(args.polls, args.interval)