#!/bin/sh
# Unit tests for statistics operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/stats.sh"
. "$LIBDIR/tasks.sh"
. "$LIBDIR/topics.sh"

echo "${BLUE}Running Statistics Tests${NC}"
echo "========================================"

# Test 1: Status counts
setup_test
create_task "TODO task 1" -s "TODO" > /dev/null 2>&1
create_task "TODO task 2" -s "TODO" > /dev/null 2>&1
create_task "IN_PROGRESS task" -s "IN_PROGRESS" > /dev/null 2>&1
create_task "DONE task" -s "DONE" > /dev/null 2>&1

result=$(get_status_counts)
assert_contains "$result" "TODO" "Status counts should include TODO"
assert_contains "$result" "IN_PROGRESS" "Status counts should include IN_PROGRESS"
assert_contains "$result" "DONE" "Status counts should include DONE"
teardown_test

# Test 2: Priority counts
setup_test
create_task "High priority" -p 1 > /dev/null 2>&1
create_task "Medium priority" -p 5 > /dev/null 2>&1
create_task "Low priority" -p 10 > /dev/null 2>&1
create_task "No priority" > /dev/null 2>&1

result=$(get_priority_counts)
assert_contains "$result" "1" "Priority counts should include priority 1"
assert_contains "$result" "5" "Priority counts should include priority 5"
assert_contains "$result" "None" "Priority counts should include None"
teardown_test

# Test 3: Date counts
setup_test
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at, due_date, completed_at) VALUES (1, 'Task 1', 'TODO', '2024-01-15', '2024-01-20', NULL);"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at, due_date, completed_at) VALUES (1, 'Task 2', 'DONE', '2024-01-16', '2024-01-22', '2024-01-18');"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at, due_date, completed_at) VALUES (1, 'Task 3', 'TODO', '2024-01-15', '2020-01-01', NULL);"

result=$(get_date_counts)
assert_contains "$result" "2024-01-15" "Date counts should include creation date"
assert_contains "$result" "2024-01-20" "Date counts should include due date"
assert_contains "$result" "Overdue" "Date counts should show overdue tasks"
teardown_test

# Test 4: Topic counts
setup_test
create_task "Task 1" > /dev/null 2>&1
create_task "Task 2" > /dev/null 2>&1
create_task "Task 3" > /dev/null 2>&1

task1_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 1';")
task2_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 2';")

tag_task "$task1_id" "work" > /dev/null 2>&1
tag_task "$task2_id" "work" > /dev/null 2>&1
tag_task "$task2_id" "urgent" > /dev/null 2>&1

result=$(get_topic_counts)
assert_contains "$result" "work" "Topic counts should include work"
assert_contains "$result" "urgent" "Topic counts should include urgent"
teardown_test

# Test 5: User counts
setup_test
# Directly insert users and tasks into database
sqlite3 "$TEST_DB" "INSERT INTO users (user) VALUES ('alice');"
sqlite3 "$TEST_DB" "INSERT INTO users (user) VALUES ('bob');"

alice_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'alice';")
bob_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'bob';")

sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($alice_id, 'Alice task 1', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($alice_id, 'Alice task 2', 'TODO', datetime('now'));"
sqlite3 "$TEST_DB" "INSERT INTO tasks (user_id, content, status, created_at) VALUES ($bob_id, 'Bob task 1', 'TODO', datetime('now'));"

result=$(get_user_counts)
assert_contains "$result" "alice" "User counts should include alice"
assert_contains "$result" "bob" "User counts should include bob"
teardown_test

# Test 6: User subscription counts
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
subscribe_topic -u testuser "personal" > /dev/null 2>&1
subscribe_topic -u testuser "urgent" > /dev/null 2>&1

result=$(get_user_subscription_counts)
assert_contains "$result" "testuser" "Subscription counts should include testuser"
assert_contains "$result" "3" "Subscription counts should show count of 3"
teardown_test

# Test 7: Tasks per topic
setup_test
create_task "Task 1" > /dev/null 2>&1
create_task "Task 2" > /dev/null 2>&1
create_task "Task 3" > /dev/null 2>&1
create_task "Task 4" > /dev/null 2>&1

task1_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 1';")
task2_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 2';")
task3_id=$(sqlite3 "$TEST_DB" "SELECT id FROM tasks WHERE content = 'Task 3';")

tag_task "$task1_id" "work" > /dev/null 2>&1
tag_task "$task2_id" "work" > /dev/null 2>&1
tag_task "$task3_id" "work" > /dev/null 2>&1
tag_task "$task1_id" "urgent" > /dev/null 2>&1

result=$(get_tasks_per_topic)
assert_contains "$result" "work" "Tasks per topic should include work"
assert_contains "$result" "urgent" "Tasks per topic should include urgent"
teardown_test

# Test 8: Show all stats
setup_test
create_task "Sample task" -p 1 -s "TODO" > /dev/null 2>&1

result=$(show_stats)
assert_contains "$result" "Total Tasks" "Stats should show total tasks"
assert_contains "$result" "Status Counts" "Stats should show status counts"
assert_contains "$result" "Priority Counts" "Stats should show priority counts"
teardown_test

# Test 9: Show specific stats (--status flag)
setup_test
create_task "Task 1" -s "TODO" > /dev/null 2>&1

result=$(show_stats --status)
assert_contains "$result" "Status Counts" "Should show status counts with --status flag"
assert_not_contains "$result" "Priority Counts" "Should not show priority counts with --status flag"
teardown_test

# Test 10: Show specific stats (--priority flag)
setup_test
create_task "Task 1" -p 1 > /dev/null 2>&1

result=$(show_stats --priority)
assert_contains "$result" "Priority Counts" "Should show priority counts with --priority flag"
assert_not_contains "$result" "Status Counts" "Should not show status counts with --priority flag"
teardown_test

print_summary
