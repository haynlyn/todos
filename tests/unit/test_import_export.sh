#!/bin/sh
# Unit tests for import/export operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/import_export.sh"

FIXTURES_DIR="$(dirname "$0")/../fixtures"

echo "${BLUE}Running Import/Export Tests${NC}"
echo "========================================"

# Test 1: Import todo.txt file
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_db_count "tasks" 11 "Should have 11 tasks after import"
teardown_test

# Test 2: Import with priorities
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "tasks" "priority = 1" "Should have priority A (1) task"
assert_row_exists "tasks" "priority = 2" "Should have priority B (2) task"
assert_row_exists "tasks" "priority = 3" "Should have priority C (3) task"
teardown_test

# Test 3: Import with completed tasks
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "tasks" "status = 'DONE'" "Should have completed tasks"
completed_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'DONE';")
assert_equal "3" "$completed_count" "Should have 3 completed tasks"
teardown_test

# Test 4: Import with completion dates
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "tasks" "completed_at = '2024-01-18'" "Should have task completed on 2024-01-18"
assert_row_exists "tasks" "completed_at = '2024-01-17'" "Should have task completed on 2024-01-17"
teardown_test

# Test 5: Import with due dates
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "tasks" "due_date = '2024-01-20'" "Should have task due on 2024-01-20"
assert_row_exists "tasks" "due_date = '2024-02-01'" "Should have task due on 2024-02-01"
teardown_test

# Test 6: Import creates topics from @contexts and +projects
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "topics" "topic = 'phone'" "Should create 'phone' topic from @phone"
assert_row_exists "topics" "topic = 'family'" "Should create 'family' topic from +family"
assert_row_exists "topics" "topic = 'work'" "Should create 'work' topic from +work"
teardown_test

# Test 7: Import links tasks to topics
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content LIKE '%Call Mom%';")
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'family';")
assert_row_exists "task_topics" "task_id = $task_id AND topic_id = $topic_id" "Task should be linked to family topic"
teardown_test

# Test 8: Import with note: tag (note becomes title in our schema)
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
assert_row_exists "tasks" "content LIKE '%Research%'" "Should import task line as content"
teardown_test

# Test 9: Export basic tasks
setup_test
# Manually create tasks (content is required)
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES (1, 'Test task', 'TODO', '2024-01-15');"
export_file="/tmp/test_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
assert_file_exists "$export_file" "Export file should be created"
content=$(cat "$export_file")
assert_contains "$content" "Test task" "Export should contain task content"
rm -f "$export_file"
teardown_test

# Test 10: Export with priority
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'Priority task', 1, 'TODO', '2024-01-15');"
export_file="/tmp/test_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
content=$(cat "$export_file")
assert_contains "$content" "(A)" "Export should contain priority (A)"
rm -f "$export_file"
teardown_test

# Test 11: Export completed task with completion date
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at, completed_at) VALUES (1, 'Done task', 'DONE', '2024-01-10', '2024-01-15');"
export_file="/tmp/test_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
content=$(cat "$export_file")
assert_contains "$content" "x 2024-01-15" "Export should contain completion marker and date"
rm -f "$export_file"
teardown_test

# Test 12: Export with due date
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, due_date, created_at) VALUES (1, 'Deadline task', 'TODO', '2024-12-31', '2024-01-15');"
export_file="/tmp/test_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
content=$(cat "$export_file")
assert_contains "$content" "due:2024-12-31" "Export should contain due date tag"
rm -f "$export_file"
teardown_test

# Test 13: Round-trip test (import → export → import → verify)
setup_test
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
original_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")

export_file="/tmp/test_roundtrip_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1

# Clear database and re-import
sqlite3 "$TEST_DB" "DELETE FROM tasks; DELETE FROM task_topics; DELETE FROM topics;"
import_from_todotxt "$export_file" > /dev/null 2>&1
new_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")

assert_equal "$original_count" "$new_count" "Round-trip should preserve task count"
rm -f "$export_file"
teardown_test

# Test 14: Export filters - incomplete only
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES (1, 'TODO task', 'TODO', '2024-01-15');"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES (1, 'DONE task', 'DONE', '2024-01-15');"
export_file="/tmp/test_export_incomplete_$$.txt"
export_to_todotxt "$export_file" -i > /dev/null 2>&1
content=$(cat "$export_file")
assert_contains "$content" "TODO task" "Export should contain incomplete task"
assert_not_contains "$content" "DONE task" "Export should not contain completed task"
rm -f "$export_file"
teardown_test

print_summary
