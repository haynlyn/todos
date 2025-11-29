#!/bin/sh
# Integration tests for complete workflows

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/db.sh"
. "$LIBDIR/tasks.sh"
. "$LIBDIR/topics.sh"
. "$LIBDIR/import_export.sh"
. "$LIBDIR/build.sh"

FIXTURES_DIR="$(dirname "$0")/../fixtures"

echo "${BLUE}Running Workflow Integration Tests${NC}"
echo "========================================"

# Test 1: Complete user workflow (init → create → tag → list → export)
setup_test
# Create tasks
create_task "Task 1" -p 1 > /dev/null 2>&1
create_task "Task 2" -p 2 > /dev/null 2>&1
create_task "Task 3" > /dev/null 2>&1

# Tag tasks
task1_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 1';")
task2_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 2';")
tag_task "$task1_id" "urgent" > /dev/null 2>&1
tag_task "$task2_id" "work" > /dev/null 2>&1

# List tasks
result=$(list_tasks 2>/dev/null)
assert_contains "$result" "Task 1" "Workflow: List should show Task 1"

# Export
export_file="/tmp/workflow_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
assert_file_exists "$export_file" "Workflow: Export file should exist"
rm -f "$export_file"

assert_db_count "tasks" 3 "Workflow: Should have 3 tasks"
assert_db_count "topics" 2 "Workflow: Should have 2 topics"
teardown_test

# Test 2: Build from fixtures → subscribe → filter workflow
setup_test
# Build from fixtures
build_from_files --from all -d "$FIXTURES_DIR" > /dev/null 2>&1
initial_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")

# Subscribe to a topic (this creates the topic if needed)
subscribe_topic "work" > /dev/null 2>&1

# Create a task and tag it
create_task "Work task" > /dev/null 2>&1
work_task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Work task';")
tag_task "$work_task_id" "work" > /dev/null 2>&1

# Filter by topic
result=$(list_tasks -t "work" 2>/dev/null)
assert_contains "$result" "Work task" "Workflow: Should filter by topic"

assert_contains "$(test $initial_count -gt 10 && echo 'yes' || echo 'no')" "yes" "Workflow: Build should create many tasks"
teardown_test

# Test 3: Multi-user collaboration scenario
setup_test
# Add users
add_user "alice" > /dev/null 2>&1
add_user "bob" > /dev/null 2>&1

# Get user IDs
alice_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'alice';")
bob_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'bob';")

# Create tasks for different users
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($alice_id, 'Alice task', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($bob_id, 'Bob task', 'TODO', datetime('now'));"

# Create shared project
sqlite3 "$TEST_DB" "INSERT INTO projects (project) VALUES ('shared-project');"
project_id=$(sqlite3 "$TEST_DB" "SELECT id FROM projects WHERE project = 'shared-project';")

# Link users to project
sqlite3 "$TEST_DB" "INSERT INTO project_users (project_id, task_id) VALUES ($project_id, $alice_id);"
sqlite3 "$TEST_DB" "INSERT INTO project_users (project_id, task_id) VALUES ($project_id, $bob_id);"

assert_db_count "users" 3 "Multi-user: Should have 3 users (testuser, alice, bob)"
assert_db_count "tasks" 2 "Multi-user: Should have 2 tasks"
teardown_test

# Test 4: Import → modify → export workflow
setup_test
# Import
import_from_todotxt "$FIXTURES_DIR/todo.txt" > /dev/null 2>&1
initial_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")

# Modify some tasks
task_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks LIMIT 1;")
set_status "$task_id" "IN_PROGRESS" > /dev/null 2>&1
set_priority "$task_id" 1 > /dev/null 2>&1

# Add new task
create_task "New task after import" > /dev/null 2>&1
new_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
assert_equal "$((initial_count + 1))" "$new_count" "Import workflow: Should have one more task after creation"

# Export
export_file="/tmp/import_modify_export_$$.txt"
export_to_todotxt "$export_file" -a > /dev/null 2>&1
export_content=$(cat "$export_file")
assert_contains "$export_content" "New task after import" "Export should contain new task"
rm -f "$export_file"
teardown_test

# Test 5: Topic subscription workflow
setup_test
# Subscribe to topics
subscribe_topic -u testuser "work" > /dev/null 2>&1
subscribe_topic -u testuser "personal" > /dev/null 2>&1
subscribe_topic -u testuser "urgent" > /dev/null 2>&1

# Create tasks for topics
create_task "Work task 1" > /dev/null 2>&1
create_task "Personal task 1" > /dev/null 2>&1

work_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Work task 1';")
personal_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Personal task 1';")

tag_task "$work_id" "work" > /dev/null 2>&1
tag_task "$personal_id" "personal" > /dev/null 2>&1

# Verify subscriptions
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
sub_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM user_topics WHERE user_id = $user_id;")
assert_equal "3" "$sub_count" "Topic workflow: Should have 3 subscriptions"

# Unsubscribe from one
unsubscribe_topic -u testuser "urgent" > /dev/null 2>&1
sub_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM user_topics WHERE user_id = $user_id;")
assert_equal "2" "$sub_count" "Topic workflow: Should have 2 subscriptions after unsubscribe"
teardown_test

print_summary
