import pandas as pd
import psycopg2
from psycopg2 import sql
import os
import glob

# Configuration
CSV_FOLDER = r"C:\Users\olivi\crypto_gaming_pipeline\data\Metaverse coins"
DB_CONFIG = {
    "host": "localhost",
    "database": "crypto_gaming",
    "user": "postgres",
    "password": REDACTED" ",
    "port": 5432
}

# Raw Table
create_table_sql = """
CREATE TABLE IF NOT EXISTS raw_token_prices (
    id              SERIAL PRIMARY KEY,
    token_name      VARCHAR(100),
    date            DATE,
    open            NUMERIC(20, 8),
    high            NUMERIC(20, 8),
    low             NUMERIC(20, 8),
    close           NUMERIC(20, 8),
    volume          BIGINT,
    currency        VARCHAR(10),
    loaded_at       TIMESTAMP DEFAULT NOW()
);
"""

# Load CSVs
def load_csvs(folder):
    all_files = glob.glob(os.path.join(folder, "*.csv"))
    dfs = []
    for filepath in all_files:
        df = pd.read_csv(filepath)
        token_name = os.path.splitext(os.path.basename(filepath))[0]
        df["token_name"] = token_name
        dfs.append(df)
    combined = pd.concat(dfs, ignore_index=True)
    return combined

# Clean Data
def clean_data(df):
    # Standardize column names to lowercase
    df.columns = df.columns.str.lower().str.strip()

    # Parse dates
    df["date"] = pd.to_datetime(df["date"], errors="coerce")

    # Drop rows where date couldn't be parsed
    df = df.dropna(subset=["date"])

    # Standardize currency to uppercase
    df["currency"] = df["currency"].str.upper().str.strip()

    # Drop exact duplicate rows
    df = df.drop_duplicates()

    # Drop rows missing price data
    df = df.dropna(subset=["open", "high", "low", "close"])

    # Volume can be null in some tokens, fill with 0
    df["volume"] = df["volume"].fillna(0).astype(int)

    # Standardize token_name, replaces spaces/dashes with underscores
    df["token_name"] = df["token_name"].str.replace(r"[\s\-]+", "_", regex=True)

    return df

# To postgres
def insert_to_postgres(df, config):
    conn = psycopg2.connect(**config)
    cursor = conn.cursor()

    inserted = 0
    for _, row in df.iterrows():
        cursor.execute("""
            INSERT INTO raw_token_prices 
                (token_name, date, open, high, low, close, volume, currency)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            row["token_name"],
            row["date"].date(),
            row["open"],
            row["high"],
            row["low"],
            row["close"],
            row["volume"],
            row["currency"]
        ))
        inserted += 1

    conn.commit()
    cursor.close()
    conn.close()
    print(f"Inserted {inserted} rows into raw_token_prices")

# MAIN
if __name__ == "__main__":
    print("Script started")
    # Connect and create table
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    cursor.execute(create_table_sql)
    conn.commit()
    cursor.close()
    conn.close()
    print("Table ready")

    # Load, clean, insert
    print("Loading CSVs")
    df = load_csvs(CSV_FOLDER)
    print(f"   Found {df.shape[0]} rows across {df['token_name'].nunique()} tokens")

    print("Cleaning data")
    df = clean_data(df)
    print(f"   {df.shape[0]} rows after cleaning")

    print("Inserting into PostgreSQL")
    insert_to_postgres(df, DB_CONFIG)