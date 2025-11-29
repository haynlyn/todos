#!/bin/sh

# Load test helpers
. "$(dirname "$0")/test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/build.sh"

FIXTURES_DIR="$(dirname "$0")/fixtures"

echo "Setting up test..."
setup_test

echo "Running build_from_files without --assign-to-me..."
build_from_files --from todo-files -d "$FIXTURES_DIR" 2>&1

echo ""
echo "Checking task count..."
sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;"

echo ""
echo "Sample tasks:"
sqlite3 "$TEST_DB" "SELECT id, user_id, content FROM tasks LIMIT 5;"

teardown_test
