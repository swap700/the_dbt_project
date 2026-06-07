"""
load_data_to_snowflake.py
─────────────────────────
Uploads the 9 Olist CSV files to Snowflake (OLIST_DB.RAW schema)
using the PUT + COPY INTO workflow — the fastest method for bulk loads.

PREREQUISITES:
    pip install snowflake-connector-python pandas

USAGE:
    1. Fill in your Snowflake credentials in the CONFIG block below
    2. Place all CSV files in the same folder as this script (or set DATA_DIR)
    3. Run: python load_data_to_snowflake.py
"""

import os
import glob
import snowflake.connector
from pathlib import Path

# ── CONFIG ─────────────────────────────────────────────────────────────────────
SNOWFLAKE_ACCOUNT   = os.environ.get("SNOWFLAKE_ACCOUNT", "your-account-identifier")
SNOWFLAKE_USER      = os.environ.get("SNOWFLAKE_USER", "your-username")
SNOWFLAKE_PASSWORD  = os.environ.get("SNOWFLAKE_PASSWORD", "your-password")
SNOWFLAKE_ROLE      = os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN")
SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
SNOWFLAKE_DATABASE  = "OLIST_DB"
SNOWFLAKE_SCHEMA    = "RAW"

# Folder where Olist CSV files live (default: same directory as this script)
DATA_DIR = Path(__file__).parent

# Map CSV filename → Snowflake table name
CSV_TABLE_MAP = {
    "olist_customers_dataset.csv":              "customers",
    "olist_geolocation_dataset.csv":            "geolocation",
    "olist_order_items_dataset.csv":            "order_items",
    "olist_order_payments_dataset.csv":         "order_payments",
    "olist_order_reviews_dataset.csv":          "order_reviews",
    "olist_orders_dataset.csv":                 "orders",
    "olist_products_dataset.csv":               "products",
    "olist_sellers_dataset.csv":                "sellers",
    "product_category_name_translation.csv":    "product_category_name_translation",
}
# ── END CONFIG ─────────────────────────────────────────────────────────────────


def get_connection():
    return snowflake.connector.connect(
        account=SNOWFLAKE_ACCOUNT,
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        role=SNOWFLAKE_ROLE,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA,
    )


def setup_snowflake(cursor):
    """Create database, schema, and file format if they don't exist."""
    print("Setting up Snowflake environment...")

    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {SNOWFLAKE_DATABASE}")
    cursor.execute(f"USE DATABASE {SNOWFLAKE_DATABASE}")
    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {SNOWFLAKE_SCHEMA}")
    cursor.execute(f"USE SCHEMA {SNOWFLAKE_SCHEMA}")

    # CSV file format — handles quoted fields, headers, and null strings
    cursor.execute("""
        CREATE OR REPLACE FILE FORMAT csv_format
            TYPE = 'CSV'
            FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            SKIP_HEADER = 1
            NULL_IF = ('', 'NULL', 'null', 'NA', 'N/A')
            EMPTY_FIELD_AS_NULL = TRUE
            DATE_FORMAT = 'AUTO'
            TIMESTAMP_FORMAT = 'AUTO'
    """)
    print("  ✓ Database, schema, and file format ready")


def infer_and_create_table(cursor, csv_path: Path, table_name: str):
    """
    Read the CSV header and create a Snowflake table with all TEXT columns.
    We intentionally use TEXT for raw tables — data typing happens in dbt staging.
    """
    import csv
    with open(csv_path, encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        headers = next(reader)

    columns_ddl = ",\n    ".join(f'{col.strip()} TEXT' for col in headers)
    ddl = f"""
        CREATE OR REPLACE TABLE {table_name} (
            {columns_ddl}
        )
    """
    cursor.execute(ddl)
    print(f"  ✓ Table {table_name} created ({len(headers)} columns)")


def load_csv(cursor, csv_path: Path, table_name: str):
    """Stage the CSV locally and COPY INTO the Snowflake table."""
    abs_path = str(csv_path.resolve()).replace("\\", "/")

    # PUT: upload file to Snowflake internal stage
    cursor.execute(f"PUT 'file://{abs_path}' @%{table_name} AUTO_COMPRESS=TRUE OVERWRITE=TRUE")

    # COPY INTO: load from stage into table
    result = cursor.execute(f"""
        COPY INTO {table_name}
        FROM @%{table_name}
        FILE_FORMAT = (FORMAT_NAME = csv_format)
        PURGE = TRUE
        ON_ERROR = 'CONTINUE'
    """).fetchall()

    rows_loaded = sum(r[3] for r in result) if result else 0
    print(f"  ✓ {table_name}: {rows_loaded:,} rows loaded")
    return rows_loaded


def main():
    print("\n🚀 Olist → Snowflake Data Loader")
    print("=" * 45)

    # Validate CSV files exist
    missing = []
    for csv_name in CSV_TABLE_MAP:
        if not (DATA_DIR / csv_name).exists():
            missing.append(csv_name)

    if missing:
        print("\n⚠️  Missing CSV files:")
        for f in missing:
            print(f"  - {f}")
        print(f"\nPlace the CSV files in: {DATA_DIR}")
        print("Download from: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce")
        return

    print(f"\nFound all {len(CSV_TABLE_MAP)} CSV files in {DATA_DIR}")

    # Connect and load
    with get_connection() as conn:
        with conn.cursor() as cursor:
            setup_snowflake(cursor)

            print(f"\nLoading tables into {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}...")
            total_rows = 0
            for csv_name, table_name in CSV_TABLE_MAP.items():
                csv_path = DATA_DIR / csv_name
                print(f"\n  Processing {csv_name}...")
                infer_and_create_table(cursor, csv_path, table_name)
                rows = load_csv(cursor, csv_path, table_name)
                total_rows += rows

    print(f"\n{'=' * 45}")
    print(f"✅ Done! {total_rows:,} total rows loaded across {len(CSV_TABLE_MAP)} tables.")
    print("\nNext steps:")
    print("  1. Copy profiles.yml to ~/.dbt/profiles.yml and fill in credentials")
    print("  2. Run: dbt deps")
    print("  3. Run: dbt run")
    print("  4. Run: dbt test")
    print("  5. Run: dbt docs generate && dbt docs serve")


if __name__ == "__main__":
    main()
