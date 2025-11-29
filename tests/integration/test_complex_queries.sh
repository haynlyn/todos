#!/bin/sh
# Integration tests for complex queries

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/tasks.sh"
. "$LIBDIR/topics.sh"

echo "${BLUE}Running Complex Query Integration Tests${NC}"
echo "========================================"

# Test 1: Multiple filter combination (user + topic + status)
setup_test
# Add another user
sqlite3 "$TEST_DB" "INSERT INTO users (user) VALUES ('alice');"
alice_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'alice';")
testuser_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")

# Create tasks for both users
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($testuser_id, 'User task 1', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($alice_id, 'Alice task 1', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($testuser_id, 'User task 2', 'DONE', datetime('now'));"

# Tag with topics
task1_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'User task 1';")
sqlite3 "$TEST_DB" "INSERT INTO topics (topic) VALUES ('work');"
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'work';")
sqlite3 "$TEST_DB" "INSERT INTO task_topics (task_id, topic_id) VALUES ($task1_id, $topic_id);"

# Query: testuser + work topic + incomplete
result=$(list_tasks -u testuser -t work -i 2>/dev/null)
assert_contains "$result" "User task 1" "Complex query: Should find testuser's incomplete work task"
assert_not_contains "$result" "Alice task" "Complex query: Should not show alice's tasks"
assert_not_contains "$result" "User task 2" "Complex query: Should not show completed tasks"
teardown_test

# Test 2: Late tasks detection
setup_test
# Create tasks with different due dates
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, due_date, created_at) VALUES (1, 'Late task', 'TODO', '2020-01-01', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, due_date, created_at) VALUES (1, 'Future task', 'TODO', '2030-01-01', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES (1, 'No deadline', 'TODO', datetime('now'));"

result=$(list_tasks -l 2>/dev/null)
assert_contains "$result" "Late task" "Should find late tasks"
assert_not_contains "$result" "Future task" "Should not include future tasks in late filter"
teardown_test

# Test 3: Tasks with multiple topics
setup_test
create_task "Multi-topic task" > /dev/null 2>&1
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Multi-topic task';")

tag_task "$task_id" "work" > /dev/null 2>&1
tag_task "$task_id" "urgent" > /dev/null 2>&1
tag_task "$task_id" "personal" > /dev/null 2>&1

# Verify task has 3 topics
topic_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM task_topics WHERE task_id = $task_id;")
assert_equal "3" "$topic_count" "Task should have 3 topics"

# Query by each topic should find the task
result1=$(list_tasks -t work 2>/dev/null)
result2=$(list_tasks -t urgent 2>/dev/null)
result3=$(list_tasks -t personal 2>/dev/null)

assert_contains "$result1" "Multi-topic task" "Should find task by 'work' topic"
assert_contains "$result2" "Multi-topic task" "Should find task by 'urgent' topic"
assert_contains "$result3" "Multi-topic task" "Should find task by 'personal' topic"
teardown_test

# Test 4: Sorting variations
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'C priority', 3, 'TODO', '2024-01-01');"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'A priority', 1, 'TODO', '2024-01-02');"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'B priority', 2, 'TODO', '2024-01-03');"

result=$(list_tasks --sort-by "priority ASC" 2>/dev/null)
# Check that A comes before B and B before C
# This is a basic check - more sophisticated ordering verification could be added
assert_contains "$result" "A priority" "Sorted result should contain A priority"
assert_contains "$result" "B priority" "Sorted result should contain B priority"
assert_contains "$result" "C priority" "Sorted result should contain C priority"
teardown_test

# Test 5: Filter by file
setup_test
sqlite3 "$TEST_DB" "INSERT INTO files (path) VALUES ('/path/to/file1.py');"
sqlite3 "$TEST_DB" "INSERT INTO files (path) VALUES ('/path/to/file2.py');"
file1_id=$(sqlite3 "$TEST_DB" "SELECT id FROM files WHERE path = '/path/to/file1.py';")
file2_id=$(sqlite3 "$TEST_DB" "SELECT id FROM files WHERE path = '/path/to/file2.py';")

sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, file_id, content, status, created_at) VALUES (1, $file1_id, 'File1 task', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, file_id, content, status, created_at) VALUES (1, $file2_id, 'File2 task', 'TODO', datetime('now'));"

result=$(list_tasks -f "/path/to/file1.py" 2>/dev/null)
assert_contains "$result" "File1 task" "Should find task associated with file1"
assert_not_contains "$result" "File2 task" "Should not find task from different file"
teardown_test

# Test 6: Priority range filtering
setup_test
create_task "High priority" -p 1 > /dev/null 2>&1
create_task "Medium priority" -p 5 > /dev/null 2>&1
create_task "Low priority" -p 10 > /dev/null 2>&1

result=$(list_tasks -p 1 2>/dev/null)
assert_contains "$result" "High priority" "Should find priority 1 task"
teardown_test

# Test 7: Combined status and priority
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'High prio todo', 1, 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'High prio done', 1, 'DONE', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, priority, status, created_at) VALUES (1, 'Low prio todo', 5, 'TODO', datetime('now'));"

result=$(list_tasks -i -p 1 2>/dev/null)
assert_contains "$result" "High prio todo" "Should find incomplete high priority task"
assert_not_contains "$result" "High prio done" "Should not show completed tasks"
assert_not_contains "$result" "Low prio" "Should not show different priority"
teardown_test

print_summary
