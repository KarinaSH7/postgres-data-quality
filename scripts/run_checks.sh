#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
command -v docker >/dev/null 2>&1 || {
    printf '%s\n' 'Docker is required. See README.md for the existing PostgreSQL option.' >&2
    exit 1
}
docker compose version >/dev/null
# Use the repository-specific Compose project. Stop its disposable database on exit.
cleanup() {
    docker compose -p karina-postgres-quality down --remove-orphans
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
docker compose -p karina-postgres-quality up -d --wait
docker compose -p karina-postgres-quality exec -T db \
    psql -X -U demo -d demo -v ON_ERROR_STOP=1 -f /demo/sql/run_checks.sql
