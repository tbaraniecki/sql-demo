#!/usr/bin/env bash
# migrate.sh — apply pending SQL migrations (upward only)
#
# Usage:
#   bash migrate.sh            # apply all pending migrations
#   bash migrate.sh --status   # show applied / pending migrations
#
# Override via env vars: DB_NAME, DB_HOST, DB_PORT, DB_USER

set -euo pipefail

DB_NAME="${DB_NAME:-tpch}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-$USER}"
MIGRATIONS_DIR="$(cd "$(dirname "$0")/migrations" && pwd)"

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER"
PSQL_DB="$PSQL -d $DB_NAME"

log() { echo "[$(date +%H:%M:%S)] $*"; }
err() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }

# ── Parse arguments ───────────────────────────────────────────────────────────
STATUS=false
for arg in "$@"; do
  case "$arg" in
    --status) STATUS=true ;;
    *) err "Unknown argument: $arg" ;;
  esac
done

# ── Ensure migrations directory exists ────────────────────────────────────────
[[ -d "$MIGRATIONS_DIR" ]] || err "migrations/ directory not found."

# ── Ensure database exists ────────────────────────────────────────────────────
$PSQL -lqt | cut -d'|' -f1 | grep -qw "$DB_NAME" \
  || err "Database '$DB_NAME' does not exist. Create it first (e.g. createdb $DB_NAME)."

# ── Ensure schema_migrations table exists ─────────────────────────────────────
$PSQL_DB -q <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
    filename   TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
SQL

# ── Collect migration files ───────────────────────────────────────────────────
mapfile -t migrations < <(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort)

if [[ ${#migrations[@]} -eq 0 ]]; then
  log "No migration files found in migrations/"
  exit 0
fi

# ── --status ──────────────────────────────────────────────────────────────────
if $STATUS; then
  printf "\nMigration status for '%s':\n\n" "$DB_NAME"
  printf "  %-40s %s\n" "MIGRATION" "STATUS"
  printf "  %-40s %s\n" "---------" "------"
  for file in "${migrations[@]}"; do
    name=$(basename "$file")
    applied=$($PSQL_DB -tAq -c "SELECT 1 FROM schema_migrations WHERE filename = '$name'")
    [[ -n "$applied" ]] && status="applied" || status="pending"
    printf "  %-40s %s\n" "$name" "$status"
  done
  echo ""
  exit 0
fi

# ── Apply pending migrations ──────────────────────────────────────────────────
applied=0
skipped=0

for file in "${migrations[@]}"; do
  name=$(basename "$file")
  already=$($PSQL_DB -tAq -c "SELECT 1 FROM schema_migrations WHERE filename = '$name'")
  if [[ -n "$already" ]]; then
    log "Skip $name (already applied)"
    ((skipped++)) || true
    continue
  fi

  log "Applying $name..."
  $PSQL_DB -v ON_ERROR_STOP=1 -f "$file"
  $PSQL_DB -q -c "INSERT INTO schema_migrations (filename) VALUES ('$name');"
  log "Applied $name."
  ((applied++)) || true
done

echo ""
log "Done. Applied: $applied  Skipped: $skipped"
