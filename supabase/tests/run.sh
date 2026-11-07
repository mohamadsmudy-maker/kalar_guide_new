#!/usr/bin/env bash
# Runs the migrations + RLS tests against an empty Postgres database.
# Usage: PGHOST=... PGPORT=... PGUSER=postgres supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=${TEST_DB:-kalar_rls_test}
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
run() { psql -v ON_ERROR_STOP=1 -q -d "$DB" "$@"; }
run -f supabase/tests/00_mock_supabase.sql
for f in supabase/migrations/*.sql; do run -1 -f "$f"; done
run -f supabase/tests/10_rls_test.sql
