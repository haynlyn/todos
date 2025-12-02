#!/bin/sh
# Unit tests for configuration management (global + project-local hierarchy)

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/config.sh"

echo "${BLUE}Running Configuration Tests${NC}"
echo "========================================"

# Setup: Create temporary HOME for testing
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
HOME_BACKUP="$HOME"

# Test 1: Set and get global config
setup_test
HOME="$TEST_HOME"
set_config --global "test.key" "test_value" > /dev/null 2>&1
result=$(get_config "test.key")
assert_equal "test_value" "$result" "Set and get global config"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 2: Set and get project config
setup_test
HOME="$TEST_HOME"
cd "$PWD"  # Ensure we're in test directory
set_config "test.key" "project_value" > /dev/null 2>&1
result=$(get_config "test.key")
assert_equal "project_value" "$result" "Set and get project config"
rm -rf ".todos"  # Clean up project-local config
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 3: Project config overrides global
setup_test
HOME="$TEST_HOME"
set_config --global "priority" "3" > /dev/null 2>&1
set_config "priority" "1" > /dev/null 2>&1
result=$(get_config "priority")
assert_equal "1" "$result" "Project config overrides global"
rm -rf ".todos"  # Clean up project-local config
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 4: Fallback to global when project not set
setup_test
HOME="$TEST_HOME"
set_config --global "fallback.key" "global_value" > /dev/null 2>&1
result=$(get_config "fallback.key")
assert_equal "global_value" "$result" "Fallback to global when project not set"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 5: Update existing key
setup_test
HOME="$TEST_HOME"
set_config --global "update.key" "value1" > /dev/null 2>&1
set_config --global "update.key" "value2" > /dev/null 2>&1
result=$(get_config "update.key")
assert_equal "value2" "$result" "Update existing key"
# Verify only one line in config (XDG-compliant path)
count=$(grep -c "update.key=" "$TEST_HOME/.config/todos/config" 2>/dev/null || echo "0")
assert_equal "1" "$count" "Should have only one line for updated key"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 6: Unset global config
setup_test
HOME="$TEST_HOME"
set_config --global "unset.key" "value" > /dev/null 2>&1
unset_config --global "unset.key" > /dev/null 2>&1
get_config "unset.key" > /dev/null 2>&1
test_exit=$?
assert_equal "1" "$test_exit" "Unset global config returns error"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 7: Unset project reveals global
setup_test
HOME="$TEST_HOME"
set_config --global "reveal.key" "global_value" > /dev/null 2>&1
set_config "reveal.key" "project_value" > /dev/null 2>&1
result=$(get_config "reveal.key")
assert_equal "project_value" "$result" "Before unset: project value"
unset_config "reveal.key" > /dev/null 2>&1
result=$(get_config "reveal.key")
assert_equal "global_value" "$result" "After unset: global value revealed"
rm -rf ".todos"  # Clean up project-local config
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 8: Multiple keys in same file
setup_test
HOME="$TEST_HOME"
set_config --global "key1" "value1" > /dev/null 2>&1
set_config --global "key2" "value2" > /dev/null 2>&1
set_config --global "key3" "value3" > /dev/null 2>&1
result1=$(get_config "key1")
result2=$(get_config "key2")
result3=$(get_config "key3")
assert_equal "value1" "$result1" "Multiple keys: key1"
assert_equal "value2" "$result2" "Multiple keys: key2"
assert_equal "value3" "$result3" "Multiple keys: key3"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 9: Preserve other keys on unset
setup_test
HOME="$TEST_HOME"
set_config --global "preserve.key1" "value1" > /dev/null 2>&1
set_config --global "preserve.key2" "value2" > /dev/null 2>&1
set_config --global "preserve.key3" "value3" > /dev/null 2>&1
unset_config --global "preserve.key2" > /dev/null 2>&1
result1=$(get_config "preserve.key1")
result3=$(get_config "preserve.key3")
assert_equal "value1" "$result1" "Preserve key1 after unsetting key2"
assert_equal "value3" "$result3" "Preserve key3 after unsetting key2"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 10: Value with spaces
setup_test
HOME="$TEST_HOME"
set_config --global "spaces.key" "value with spaces" > /dev/null 2>&1
result=$(get_config "spaces.key")
assert_equal "value with spaces" "$result" "Value with spaces"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 11: Key with dots (namespace)
setup_test
HOME="$TEST_HOME"
set_config --global "list.default_sort" "priority" > /dev/null 2>&1
result=$(get_config "list.default_sort")
assert_equal "priority" "$result" "Key with dots (namespace)"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 12: Get non-existent key
setup_test
HOME="$TEST_HOME"
get_config "nonexistent.key" > /dev/null 2>&1
test_exit=$?
assert_equal "1" "$test_exit" "Get non-existent key returns error"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 13: Config directory creation (global)
setup_test
HOME="$TEST_HOME"
# Directory doesn't exist yet (XDG-compliant path)
test ! -d "$TEST_HOME/.config/todos" || rm -rf "$TEST_HOME/.config/todos"
set_config --global "test.key" "value" > /dev/null 2>&1
test -d "$TEST_HOME/.config/todos"
dir_exists=$?
assert_equal "0" "$dir_exists" "Global config directory created"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 14: Config directory creation (project)
setup_test
HOME="$TEST_HOME"
# Directory doesn't exist yet
test ! -d ".todos" || rm -rf ".todos"
set_config "test.key" "value" > /dev/null 2>&1
test -d ".todos"
dir_exists=$?
assert_equal "0" "$dir_exists" "Project config directory created"
rm -rf ".todos"  # Clean up project-local config
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 15: get_config_or_default with set value
setup_test
HOME="$TEST_HOME"
set_config --global "default.test" "actual_value" > /dev/null 2>&1
result=$(get_config_or_default "default.test" "default_value")
assert_equal "actual_value" "$result" "get_config_or_default returns actual value"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 16: get_config_or_default with unset value
setup_test
HOME="$TEST_HOME"
result=$(get_config_or_default "unset.test" "default_value")
assert_equal "default_value" "$result" "get_config_or_default returns default"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 17: Value with equals sign
setup_test
HOME="$TEST_HOME"
set_config --global "equals.key" "value=with=equals" > /dev/null 2>&1
result=$(get_config "equals.key")
assert_equal "value=with=equals" "$result" "Value with equals sign"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Test 18: Special characters in value
setup_test
HOME="$TEST_HOME"
set_config --global "special.key" "value/with/slashes" > /dev/null 2>&1
result=$(get_config "special.key")
assert_equal "value/with/slashes" "$result" "Special characters (slashes)"
HOME="$HOME_BACKUP"
rm -rf "$TEST_HOME"
TEST_HOME="/tmp/todos_test_home_$$"
mkdir -p "$TEST_HOME"
teardown_test

# Cleanup
rm -rf "$TEST_HOME"

print_summary
