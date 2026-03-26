#!/usr/bin/env bash
# create_db.sh — generate TPC-H data and load it into PostgreSQL
#
# Usage:
#   bash create_db.sh
#   SCALE_FACTOR=0.1 bash create_db.sh   # ~100MB quick test
#
# Override via env vars: DB_NAME, DB_HOST, DB_PORT, DB_USER, SCALE_FACTOR
# Run migrate.sh first to apply schema migrations before loading data.

set -euo pipefail

DB_NAME="${DB_NAME:-tpch}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-$USER}"
SCALE_FACTOR="${SCALE_FACTOR:-1}"
DBGEN_DIR="tpch-dbgen"
DATA_DIR="tpch-data"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER"
PSQL_DB="$PSQL -d $DB_NAME"

log() { echo "[$(date +%H:%M:%S)] $*"; }
err() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
log "Checking prerequisites..."
for cmd in psql gcc make git; do
  command -v "$cmd" &>/dev/null || err "'$cmd' not found."
done

# ── 2. Clone and compile dbgen ────────────────────────────────────────────────
if [[ ! -d "$DBGEN_DIR" ]]; then
  log "Cloning tpch-dbgen..."
  git clone https://github.com/electrum/tpch-dbgen "$DBGEN_DIR"
fi

if [[ ! -f "$DBGEN_DIR/dbgen" ]]; then
  log "Compiling dbgen..."
  make -C "$DBGEN_DIR" -s
fi

# ── 3. Generate data files ────────────────────────────────────────────────────
mkdir -p "$DATA_DIR"

if [[ ! -f "$DATA_DIR/lineitem.tbl" ]]; then
  log "Generating data at scale factor $SCALE_FACTOR..."
  (cd "$DBGEN_DIR" && ./dbgen -f -s "$SCALE_FACTOR")
  mv "$DBGEN_DIR"/*.tbl "$DATA_DIR"/
  log "Data generation complete."
else
  log "Data files already exist, skipping generation."
fi

# ── 4. Create database ────────────────────────────────────────────────────────
if ! $PSQL -lqt | cut -d'|' -f1 | grep -qw "$DB_NAME"; then
  createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
  log "Database '$DB_NAME' created."
else
  log "Database '$DB_NAME' already exists."
fi

# ── 5. Load data ──────────────────────────────────────────────────────────────
load_table() {
  local table=$1
  local count
  count=$($PSQL_DB -tAq -c "SELECT COUNT(*) FROM $table")
  if [[ "$count" -gt 0 ]]; then
    log "Table $table already has $count rows, skipping."
    return
  fi
  log "Loading $table..."
  sed 's/|$//' "$SCRIPT_DIR/$DATA_DIR/${table}.tbl" \
    | $PSQL_DB -c "\copy $table FROM STDIN WITH (FORMAT csv, DELIMITER '|')"
}

load_table region
load_table nation
load_table part
load_table supplier
load_table partsupp
load_table customer
load_table orders
load_table lineitem

# ── 6. Row counts ─────────────────────────────────────────────────────────────
log "Row counts:"
$PSQL_DB -c "
SELECT table_name,
       (xpath('/row/c/text()', query_to_xml(
         'SELECT COUNT(*) AS c FROM ' || table_name, false, true, '')))[1]::text::bigint AS rows
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name != 'schema_migrations'
ORDER BY table_name;"

log "Done. Connect: psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
