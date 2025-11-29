#!/bin/sh
# Test framework helpers

# Colors for output
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Current test database
TEST_DB=""

# Set test user for all library functions
export TODOS_TEST_USER="testuser"

# Setup test environment
setup_test() {
  # Create temporary test database
  TEST_DB="/tmp/todos_test_$$.db"

  # Export for library functions to use
  export DB="$TEST_DB"

  # Initialize main database - find schema file
  # Try different locations based on where test is run from
  if [ -f "$(dirname "$0")/../../share/schema.sql" ]; then
    SCHEMA_PATH="$(dirname "$0")/../../share/schema.sql"
  elif [ -f "$(dirname "$0")/../share/schema.sql" ]; then
    SCHEMA_PATH="$(dirname "$0")/../share/schema.sql"
  elif [ -f "./share/schema.sql" ]; then
    SCHEMA_PATH="./share/schema.sql"
  elif [ -f "../share/schema.sql" ]; then
    SCHEMA_PATH="../share/schema.sql"
  else
    echo "Error: Cannot find schema.sql"
    return 1
  fi

  # Load schema for main database (includes users tables now)
  sqlite3 "$TEST_DB" < "$SCHEMA_PATH" 2>/dev/null

  # Add test user to database
  sqlite3 "$TEST_DB" "INSERT INTO users (user, role) VALUES ('testuser', 'admin');" 2>/dev/null

  # Set test user environment variable for library functions
  export TODOS_TEST_USER="testuser"
}

# Teardown test environment
teardown_test() {
  if [ -f "$TEST_DB" ]; then
    rm -f "$TEST_DB"
  fi
}

# Add user to test database
add_test_user() {
  username="$1"
  role="${2:-user}"
  sqlite3 "$TEST_DB" "INSERT OR IGNORE INTO users (user, role) VALUES ('$username', '$role');" 2>/dev/null
}

# Assertion helpers
assert_equal() {
  expected="$1"
  actual="$2"
  message="${3:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  Expected: %s\n" "$expected"
    printf "  Actual:   %s\n" "$actual"
    return 1
  fi
}

assert_not_equal() {
  not_expected="$1"
  actual="$2"
  message="${3:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$not_expected" != "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  Should not equal: %s\n" "$not_expected"
    printf "  Actual:           %s\n" "$actual"
    return 1
  fi
}

assert_contains() {
  haystack="$1"
  needle="$2"
  message="${3:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  Haystack: %s\n" "$haystack"
    printf "  Needle:   %s\n" "$needle"
    return 1
  fi
}

assert_not_contains() {
  haystack="$1"
  needle="$2"
  message="${3:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  Haystack: %s\n" "$haystack"
    printf "  Should not contain: %s\n" "$needle"
    return 1
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  fi
}

assert_db_count() {
  table="$1"
  expected_count="$2"
  message="${3:-DB count assertion failed}"

  actual_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM $table;")
  assert_equal "$expected_count" "$actual_count" "$message"
}

assert_row_exists() {
  table="$1"
  where_clause="$2"
  message="${3:-Row existence assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM $table WHERE $where_clause;")

  if [ "$count" -gt 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  No rows found in %s WHERE %s\n" "$table" "$where_clause"
    return 1
  fi
}

assert_row_not_exists() {
  table="$1"
  where_clause="$2"
  message="${3:-Row non-existence assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM $table WHERE $where_clause;")

  if [ "$count" -eq 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  Found %s rows in %s WHERE %s\n" "$count" "$table" "$where_clause"
    return 1
  fi
}

assert_file_exists() {
  file_path="$1"
  message="${2:-File should exist}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$message"
    printf "  File not found: %s\n" "$file_path"
    return 1
  fi
}

# Print test summary
print_summary() {
  echo ""
  echo "========================================"
  if [ $TESTS_FAILED -eq 0 ]; then
    printf "${GREEN}All tests passed!${NC}\n"
  else
    printf "${RED}Some tests failed!${NC}\n"
  fi
  echo "Total:  $TESTS_RUN"
  printf "${GREEN}Passed: $TESTS_PASSED${NC}\n"
  if [ $TESTS_FAILED -gt 0 ]; then
    printf "${RED}Failed: $TESTS_FAILED${NC}\n"
  fi
  echo "========================================"

  # Return non-zero if any tests failed
  return $TESTS_FAILED
}

# Source libraries (modify paths as needed based on test location)
get_lib_path() {
  # Try from tests directory (most common - running from tests/)
  if [ -d "../lib" ] && [ -f "../lib/build.sh" ]; then
    echo "$(cd "../lib" && pwd)"
  # For unit tests (from tests/unit/)
  elif [ -d "$(dirname "$0")/../../lib" ] && [ -f "$(dirname "$0")/../../lib/build.sh" ]; then
    echo "$(cd "$(dirname "$0")/../../lib" && pwd)"
  # For integration tests (from tests/integration/)
  elif [ -d "$(dirname "$0")/../lib" ] && [ -f "$(dirname "$0")/../lib/build.sh" ]; then
    echo "$(cd "$(dirname "$0")/../lib" && pwd)"
  # For direct invocation from project root
  elif [ -d "./lib" ] && [ -f "./lib/build.sh" ]; then
    echo "$(cd "./lib" && pwd)"
  # Fallback to installed location
  else
    echo "$HOME/.local/lib/todos"
  fi
}

# Note: get_db_path is defined in each library file and checks $DB environment variable
# We don't need to override it here since we export DB in setup_test()
