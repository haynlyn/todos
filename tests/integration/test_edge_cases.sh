#!/bin/sh
# Integration tests for edge cases and error handling

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/tasks.sh"
. "$LIBDIR/topics.sh"
. "$LIBDIR/import_export.sh"

echo "${BLUE}Running Edge Case Integration Tests${NC}"
echo "========================================"

# Test 1: Create task with missing content (should fail)
setup_test
result=$(create_task 2>&1)
assert_contains "$result" "Error" "Should error when content is missing"
assert_db_count "tasks" 0 "Should not create task without content"
teardown_test

# Test 2: Delete non-existent task
setup_test
result=$(delete_task 99999 2>&1)
# Command should run without error even if task doesn't exist
assert_db_count "tasks" 0 "DB should remain empty"
teardown_test

# Test 3: Update non-existent task
setup_test
result=$(update_task -i 99999 -t "New title" 2>&1)
# Should not crash, may show no updates
assert_db_count "tasks" 0 "DB should remain empty"
teardown_test

# Test 4: Very long task content (1000+ characters)
setup_test
long_content="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Extra text to make it even longer and test the limits of content storage in the database system."

create_task "$long_content" > /dev/null 2>&1
stored_content=$(sqlite3 "$TEST_DB" "SELECT content FROM tasks WHERE content = '$long_content';")
assert_equal "$long_content" "$stored_content" "Very long content should be stored completely"
teardown_test

# Test 5: Task with no creation date (NULL)
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status) VALUES (1, 'No date task', 'TODO');"
assert_row_exists "tasks" "content = 'No date task'" "Task with no creation date should exist"
teardown_test

# Test 6: Invalid date format
setup_test
create_task "Invalid date task" -d "not-a-date" > /dev/null 2>&1
# Should still create task (invalid date is stored as-is)
assert_row_exists "tasks" "content = 'Invalid date task'" "Task should be created even with invalid date"
teardown_test

# Test 7: Task with all NULL optional fields
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES (1, 'Minimal task', 'TODO', datetime('now'));"
task=$(sqlite3 "$TEST_DB" "SELECT * FROM tasks WHERE content = 'Minimal task';")
assert_contains "$task" "Minimal task" "Minimal task should exist"
teardown_test

# Test 8: Special characters in various fields
setup_test
create_task "Task with <html> & \"quotes\" and 'apostrophes'" > /dev/null 2>&1
assert_row_exists "tasks" "content LIKE '%html%'" "Should handle special characters"
teardown_test

# Test 9: Empty todo.txt import
setup_test
empty_file="/tmp/empty_todo_$$.txt"
touch "$empty_file"
import_from_todotxt "$empty_file" > /dev/null 2>&1
assert_db_count "tasks" 0 "Empty import should create no tasks"
rm -f "$empty_file"
teardown_test

# Test 10: Malformed todo.txt lines
setup_test
malformed_file="/tmp/malformed_todo_$$.txt"
cat > "$malformed_file" <<EOF
This is a task without proper format
(Z) Invalid priority letter
2024-99-99 Invalid date format
x Invalid completion marker
EOF
import_from_todotxt "$malformed_file" > /dev/null 2>&1
# Should import what it can parse
task_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
assert_contains "$(test $task_count -ge 1 && echo 'yes' || echo 'no')" "yes" "Should parse some malformed lines"
rm -f "$malformed_file"
teardown_test

# Test 11: Unsubscribe from non-existent topic
setup_test
result=$(unsubscribe_topic "nonexistent" 2>&1)
assert_contains "$result" "Error\|not found" "Should handle unsubscribing from non-existent topic"
teardown_test

# Test 12: Tag task with empty topic name
setup_test
create_task "Task to tag" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task to tag';")
result=$(tag_task "$task_id" "" 2>&1)
# Should either error or create empty topic (current behavior may vary)
# This documents the behavior for future reference
teardown_test

# Test 13: Maximum priority value
setup_test
create_task "Max priority" -p 999 > /dev/null 2>&1
priority=$(sqlite3 "$TEST_DB" "SELECT priority FROM tasks WHERE content = 'Max priority';")
assert_equal "999" "$priority" "Should handle large priority values"
teardown_test

# Test 14: Negative priority value
setup_test
create_task "Negative priority" -p -1 > /dev/null 2>&1
priority=$(sqlite3 "$TEST_DB" "SELECT priority FROM tasks WHERE content = 'Negative priority';")
assert_equal "-1" "$priority" "Should handle negative priority values"
teardown_test

# Test 15: Tasks with identical titles
setup_test
create_task "Duplicate title" > /dev/null 2>&1
create_task "Duplicate title" > /dev/null 2>&1
create_task "Duplicate title" > /dev/null 2>&1
assert_db_count "tasks" 3 "Should allow multiple tasks with same title"
teardown_test

# Test 16: Export with no tasks
setup_test
export_file="/tmp/empty_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
assert_file_exists "$export_file" "Export file should exist even with no tasks"
content=$(cat "$export_file" 2>/dev/null || echo "")
# File should be empty or contain only headers
teardown_test

print_summary
