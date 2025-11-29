#!/bin/sh
# Test runner for todos project

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

# Command line options
VERBOSE=0
UNIT_ONLY=0
INTEGRATION_ONLY=0
SPECIFIC_TEST=""

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case $1 in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -u|--unit)
      UNIT_ONLY=1
      shift
      ;;
    -i|--integration)
      INTEGRATION_ONLY=1
      shift
      ;;
    -t|--test)
      SPECIFIC_TEST="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]

Options:
  -v, --verbose         Show verbose output from tests
  -u, --unit            Run only unit tests
  -i, --integration     Run only integration tests
  -t, --test <file>     Run a specific test file
  -h, --help            Show this help message

Examples:
  $0                              # Run all tests
  $0 -u                           # Run only unit tests
  $0 -i                           # Run only integration tests
  $0 -t test_tasks.sh             # Run specific test file
  $0 -v -t test_import_export.sh  # Run specific test with verbose output

EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Initialize counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FILES_RUN=0
FILES_FAILED=0

# Function to run a test file
run_test_file() {
  test_file="$1"
  test_name=$(basename "$test_file")

  printf "${BLUE}Running${NC} %s...\n" "$test_name"

  if [ $VERBOSE -eq 1 ]; then
    sh "$test_file"
    result=$?
  else
    output=$(sh "$test_file" 2>&1)
    result=$?
  fi

  FILES_RUN=$((FILES_RUN + 1))

  if [ $result -eq 0 ]; then
    printf "${GREEN}✓ PASSED${NC} %s\n" "$test_name"
  else
    printf "${RED}✗ FAILED${NC} %s\n" "$test_name"
    FILES_FAILED=$((FILES_FAILED + 1))
    if [ $VERBOSE -eq 0 ]; then
      echo "$output"
    fi
  fi

  echo ""
  return $result
}

# Main execution
echo "========================================"
echo "    Todos Project Test Suite"
echo "========================================"
echo ""

# Run specific test if requested
if [ -n "$SPECIFIC_TEST" ]; then
  # Check if file exists in unit or integration directory
  if [ -f "$TEST_DIR/unit/$SPECIFIC_TEST" ]; then
    run_test_file "$TEST_DIR/unit/$SPECIFIC_TEST"
    exit $?
  elif [ -f "$TEST_DIR/integration/$SPECIFIC_TEST" ]; then
    run_test_file "$TEST_DIR/integration/$SPECIFIC_TEST"
    exit $?
  elif [ -f "$SPECIFIC_TEST" ]; then
    run_test_file "$SPECIFIC_TEST"
    exit $?
  else
    echo "${RED}Error:${NC} Test file not found: $SPECIFIC_TEST"
    exit 1
  fi
fi

# Run unit tests
if [ $INTEGRATION_ONLY -eq 0 ]; then
  echo "${BLUE}━━━ Unit Tests ━━━${NC}"
  echo ""

  for test_file in "$TEST_DIR/unit"/*.sh; do
    if [ -f "$test_file" ]; then
      run_test_file "$test_file"
    fi
  done
fi

# Run integration tests
if [ $UNIT_ONLY -eq 0 ]; then
  echo "${BLUE}━━━ Integration Tests ━━━${NC}"
  echo ""

  for test_file in "$TEST_DIR/integration"/*.sh; do
    if [ -f "$test_file" ]; then
      run_test_file "$test_file"
    fi
  done
fi

# Print final summary
echo "========================================"
echo "           Test Summary"
echo "========================================"
echo "Test files run: $FILES_RUN"

if [ $FILES_FAILED -eq 0 ]; then
  printf "${GREEN}All test files passed!${NC}\n"
  exit_code=0
else
  printf "${RED}Failed test files: $FILES_FAILED${NC}\n"
  exit_code=1
fi

echo "========================================"

exit $exit_code
