#!/bin/sh
# Diagnostic test to understand environment

# Load test helpers
. "$(dirname "$0")/test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/tasks.sh"

echo "=== ENVIRONMENT DIAGNOSTICS ==="
echo "TODOS_TEST_USER: ${TODOS_TEST_USER:-NOT SET}"
echo "DB: ${DB:-NOT SET}"
echo "USERS_DB: ${USERS_DB:-NOT SET}"
echo "TEST_DB: ${TEST_DB:-NOT SET}"
echo "TEST_USERS_DB: ${TEST_USERS_DB:-NOT SET}"
echo ""

echo "=== RUNNING SETUP ==="
setup_test

echo ""
echo "=== AFTER SETUP ==="
echo "TODOS_TEST_USER: ${TODOS_TEST_USER:-NOT SET}"
echo "DB: ${DB:-NOT SET}"
echo "USERS_DB: ${USERS_DB:-NOT SET}"
echo "TEST_DB: ${TEST_DB:-NOT SET}"
echo "TEST_USERS_DB: ${TEST_USERS_DB:-NOT SET}"
echo ""

echo "=== CHECKING DATABASES ==="
echo "TEST_DB exists: $(test -f "$TEST_DB" && echo YES || echo NO)"
echo "TEST_USERS_DB exists: $(test -f "$TEST_DB" && echo YES || echo NO)"
echo ""

echo "=== USERS IN DATABASE ==="
sqlite3 "$TEST_DB" "SELECT * FROM users;" 2>&1
echo ""

echo "=== CREATING TASK WITH DEBUG ==="
set -x
create_task "Debug task"
set +x
echo ""

echo "=== CHECKING TASKS ==="
sqlite3 "$TEST_DB" "SELECT * FROM tasks;" 2>&1
echo ""

echo "=== TASK COUNT ==="
sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;" 2>&1
echo ""

teardown_test
