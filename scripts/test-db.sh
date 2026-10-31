#!/usr/bin/env bash
# Runs the migration and the security tests against a throwaway database.
# Needs a local Postgres 15+; set PSQL to point at it, e.g. PSQL="psql -h localhost -U postgres".
set -euo pipefail
PSQL=${PSQL:-psql}
cd "$(dirname "$0")/../supabase"
$PSQL -q -c 'drop database if exists rpg_test' -c 'create database rpg_test'
for f in tests/stub_auth.sql migrations/*.sql tests/rls_test.sql; do
  $PSQL -q -v ON_ERROR_STOP=1 -d rpg_test -f "$f" > /dev/null
done
echo "ALL TESTS PASSED"
