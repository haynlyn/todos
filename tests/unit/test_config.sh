#!/bin/sh
# Unit tests for config operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/config.sh"

echo "${BLUE}Running Config Tests${NC}"
echo "========================================"

# Test 1: Set config value
setup_test
test_config="/tmp/test_config_$$.conf"
# Override get_config_path for testing
get_config_path() { echo "$test_config"; }

set_config "DB" "/path/to/db" > /dev/null 2>&1
assert_file_exists "$test_config" "Config file should be created"
content=$(cat "$test_config")
assert_contains "$content" "DB=/path/to/db" "Config should contain DB setting"
rm -f "$test_config"
teardown_test

# Test 2: Get config value
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

set_config "MIN_PRIORITY" "3" > /dev/null 2>&1
value=$(get_config "MIN_PRIORITY" 2>&1)
assert_contains "$value" "3" "Should retrieve config value"
rm -f "$test_config"
teardown_test

# Test 3: Update existing config value
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

set_config "DB" "/old/path" > /dev/null 2>&1
set_config "DB" "/new/path" > /dev/null 2>&1
content=$(cat "$test_config")
assert_contains "$content" "/new/path" "Config should contain updated value"
assert_not_contains "$content" "/old/path" "Config should not contain old value"
rm -f "$test_config"
teardown_test

# Test 4: Unset config value
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

set_config "TEST_KEY" "test_value" > /dev/null 2>&1
unset_config "TEST_KEY" > /dev/null 2>&1
content=$(cat "$test_config" 2>/dev/null || echo "")
assert_not_contains "$content" "TEST_KEY" "Config should not contain unset key"
rm -f "$test_config"
teardown_test

# Test 5: Get non-existent config value
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

touch "$test_config"
result=$(get_config "NONEXISTENT" 2>&1)
assert_contains "$result" "not set" "Should indicate key is not set"
rm -f "$test_config"
teardown_test

# Test 6: Multiple config values
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

set_config "KEY1" "value1" > /dev/null 2>&1
set_config "KEY2" "value2" > /dev/null 2>&1
set_config "KEY3" "value3" > /dev/null 2>&1

val1=$(get_config "KEY1" 2>&1)
val2=$(get_config "KEY2" 2>&1)
val3=$(get_config "KEY3" 2>&1)

assert_contains "$val1" "value1" "Should retrieve KEY1"
assert_contains "$val2" "value2" "Should retrieve KEY2"
assert_contains "$val3" "value3" "Should retrieve KEY3"
rm -f "$test_config"
teardown_test

# Test 7: Config with special characters in value
setup_test
test_config="/tmp/test_config_$$.conf"
get_config_path() { echo "$test_config"; }

set_config "PATH" "/path/with spaces/and-dashes" > /dev/null 2>&1
value=$(get_config "PATH" 2>&1)
assert_contains "$value" "with spaces" "Should handle spaces in values"
rm -f "$test_config"
teardown_test

print_summary
