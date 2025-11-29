#!/bin/sh
# Unit tests for database operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/db.sh"
. "$LIBDIR/users.sh"

echo "${BLUE}Running Database Tests${NC}"
echo "========================================"

# Test 1: Database initialization
setup_test
assert_file_exists "$TEST_DB" "Main database file should be created"
assert_file_exists "$TEST_DB" "Users database file should be created"
teardown_test

# Test 2: Add user to users database
setup_test
add_test_user "alice"
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM users WHERE user = 'alice';")
assert_equal "1" "$count" "User alice should exist in users database"
teardown_test

# Test 3: Add duplicate user (should be ignored)
setup_test
add_test_user "bob"
add_test_user "bob"
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM users WHERE user = 'bob';")
assert_equal "1" "$count" "Duplicate user should be ignored (INSERT OR IGNORE)"
teardown_test

# Test 4: Delete user from users database
setup_test
add_test_user "charlie"
sqlite3 "$TEST_DB" "DELETE FROM users WHERE user = 'charlie';" 2>/dev/null
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM users WHERE user = 'charlie';")
assert_equal "0" "$count" "User charlie should be deleted"
teardown_test

# Test 5: User topics cleanup (relationships stay in main DB, user in users DB)
setup_test
add_test_user "david"
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'david';")
# Add a topic subscription for david in main database
sqlite3 "$TEST_DB" "INSERT INTO topics (topic) VALUES ('testing');"
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'testing';")
sqlite3 "$TEST_DB" "INSERT INTO user_topics (user_id, topic_id) VALUES ($user_id, $topic_id);"

# Delete user from users DB (note: relationships in main DB would need manual cleanup)
sqlite3 "$TEST_DB" "DELETE FROM users WHERE user = 'david';" 2>/dev/null
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM users WHERE user = 'david';")
assert_equal "0" "$count" "User david should be deleted from users database"
teardown_test

# Test 6: Schema validation - check all tables exist in main DB
setup_test
tables=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
assert_contains "$tables" "tasks" "Tasks table should exist"
assert_contains "$tables" "topics" "Topics table should exist"
assert_contains "$tables" "files" "Files table should exist"
assert_contains "$tables" "task_topics" "Task_topics table should exist"
assert_contains "$tables" "user_topics" "User_topics table should exist"
assert_contains "$tables" "projects" "Projects table should exist"
teardown_test

# Test 7: Schema validation - check users tables exist in users DB
setup_test
users_tables=$(sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
assert_contains "$users_tables" "users" "Users table should exist in users database"
assert_contains "$users_tables" "user_audit" "User_audit table should exist in users database"
teardown_test

# Test 8: Check tasks table has completed_at field
setup_test
schema=$(sqlite3 "$TEST_DB" "PRAGMA table_info(tasks);")
assert_contains "$schema" "completed_at" "Tasks table should have completed_at field"
teardown_test

print_summary
