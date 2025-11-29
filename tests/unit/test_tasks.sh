#!/bin/sh
# Unit tests for task operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/tasks.sh"

echo "${BLUE}Running Task Tests${NC}"
echo "========================================"

# Test 1: Create simple task
setup_test
create_task "Test task" > /dev/null 2>&1
assert_row_exists "tasks" "content = 'Test task'" "Task should be created"
assert_db_count "tasks" 1 "Should have 1 task"
teardown_test

# Test 2: Create task with all fields (content + optional title)
setup_test
create_task "Task description" -t "Complex task" -p 1 -d "2024-12-31" -s "TODO" > /dev/null 2>&1
assert_row_exists "tasks" "title = 'Complex task' AND priority = 1" "Task with title and priority should be created"
assert_row_exists "tasks" "content = 'Task description'" "Task with content should be created"
assert_row_exists "tasks" "due_date = '2024-12-31'" "Task with due date should be created"
teardown_test

# Test 3: Create task with special characters
setup_test
create_task "Task with 'quotes' and \"double quotes\"" > /dev/null 2>&1
assert_row_exists "tasks" "content LIKE '%quotes%'" "Task with special characters should be created"
teardown_test

# Test 4: Delete task by ID
setup_test
create_task "Task to delete" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task to delete';")
delete_task "$task_id" > /dev/null 2>&1
assert_row_not_exists "tasks" "id = $task_id" "Task should be deleted"
teardown_test

# Test 5: Delete task by ID
setup_test
create_task "Task to delete" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task to delete';")
delete_task "$task_id" > /dev/null 2>&1
assert_row_not_exists "tasks" "content = 'Task to delete'" "Task should be deleted by ID"
teardown_test

# Test 6: Update task status
setup_test
create_task "Task to update" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task to update';")
set_status "$task_id" "DONE" > /dev/null 2>&1
assert_row_exists "tasks" "id = $task_id AND status = 'DONE'" "Task status should be updated"
teardown_test

# Test 7: Update task priority
setup_test
create_task "Priority task" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Priority task';")
set_priority "$task_id" 2 > /dev/null 2>&1
assert_row_exists "tasks" "id = $task_id AND priority = 2" "Task priority should be updated"
teardown_test

# Test 8: Update task deadline
setup_test
create_task "Deadline task" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Deadline task';")
set_deadline "$task_id" "2025-01-01" > /dev/null 2>&1
assert_row_exists "tasks" "id = $task_id AND due_date = '2025-01-01'" "Task deadline should be updated"
teardown_test

# Test 9: Rename task
setup_test
create_task "Old title" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Old title';")
rename_task "$task_id" "New title" > /dev/null 2>&1
assert_row_exists "tasks" "id = $task_id AND content = 'New title'" "Task should be renamed"
assert_row_not_exists "tasks" "content = 'Old title'" "Old title should not exist"
teardown_test

# Test 10: Tag task with topic
setup_test
create_task "Task to tag" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task to tag';")
tag_task "$task_id" "urgent" > /dev/null 2>&1
assert_row_exists "topics" "topic = 'urgent'" "Topic should be created"
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'urgent';")
assert_row_exists "task_topics" "task_id = $task_id AND topic_id = $topic_id" "Task-topic relationship should exist"
teardown_test

# Test 11: Update multiple fields at once
setup_test
create_task "Multi update" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Multi update';")
update_task -i "$task_id" -c "New content" -s "IN_PROGRESS" -p 3 > /dev/null 2>&1
assert_row_exists "tasks" "id = $task_id AND content = 'New content' AND status = 'IN_PROGRESS' AND priority = 3" "Multiple fields should be updated"
teardown_test

# Test 12: SQL injection attempt in title
setup_test
create_task "'; DROP TABLE tasks; --" > /dev/null 2>&1
assert_db_count "tasks" 1 "SQL injection should be escaped"
assert_row_exists "tasks" "content LIKE '%DROP TABLE%'" "Malicious title should be stored as text"
teardown_test

# Test 13: Very long task content
setup_test
long_content="This is a very long task content that contains more than one hundred characters to test how the system handles extremely long input strings without truncating or breaking"
create_task "$long_content" > /dev/null 2>&1
assert_row_exists "tasks" "length(content) > 100" "Long content should be stored completely"
teardown_test

# Test 14: Unicode characters in title
setup_test
create_task "Task with émojis 🎉 and ümläuts" > /dev/null 2>&1
assert_row_exists "tasks" "content LIKE '%mojis%'" "Unicode characters should be handled"
teardown_test

# Test 15: List tasks (basic)
setup_test
create_task "Task 1" > /dev/null 2>&1
create_task "Task 2" > /dev/null 2>&1
create_task "Task 3" > /dev/null 2>&1
result=$(list_tasks 2>/dev/null)
assert_contains "$result" "Task 1" "List should contain Task 1"
assert_contains "$result" "Task 2" "List should contain Task 2"
assert_contains "$result" "Task 3" "List should contain Task 3"
teardown_test

# Test 16: Filter incomplete tasks
setup_test
create_task "Incomplete task" -s "TODO" > /dev/null 2>&1
create_task "Complete task" -s "DONE" > /dev/null 2>&1
result=$(list_tasks -i 2>/dev/null)
assert_contains "$result" "Incomplete task" "List should contain incomplete task"
assert_not_contains "$result" "Complete task" "List should not contain complete task"
teardown_test

print_summary
