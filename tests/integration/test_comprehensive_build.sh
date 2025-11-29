#!/bin/sh
# Comprehensive integration test for all task sources

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load libraries
LIBDIR=$(get_lib_path)
. "$LIBDIR/db.sh"
. "$LIBDIR/tasks.sh"
. "$LIBDIR/topics.sh"
. "$LIBDIR/import_export.sh"
. "$LIBDIR/build.sh"
. "$LIBDIR/stats.sh"

FIXTURES_DIR="$(dirname "$0")/../fixtures"

echo "${BLUE}Running Comprehensive Build Integration Test${NC}"
echo "=========================================="

# Test: Build from ALL sources and verify metrics
setup_test

echo "Building from all sources..."

# 1. Import from todo.txt (large_todo.txt has 100 tasks)
echo "Importing from large_todo.txt..."
import_from_todotxt "$FIXTURES_DIR/large_todo.txt" > /dev/null 2>&1

# 2. Build from .todo files
echo "Building from .todo files..."
build_from_files --from todo-files -d "$FIXTURES_DIR" > /dev/null 2>&1

# 3. Build from TODO comments and blocks in code
echo "Building from code comments..."
build_from_files --from comments -d "$FIXTURES_DIR" > /dev/null 2>&1

echo "Building from code blocks..."
build_from_files --from blocks -d "$FIXTURES_DIR" > /dev/null 2>&1

# Now verify the metrics
echo ""
echo "Verifying task counts from all sources..."

# Count total tasks
total_tasks=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
echo "Total tasks: $total_tasks"

# Expected breakdown:
# - large_todo.txt: 100 tasks
# - demo1.todo: 5 tasks
# - demo2.todo: 4 tasks
# - project_tasks.todo: 25 tasks
# - bugs.todo: 20 tasks
# - features.todo: 20 tasks
# - sample.c: ~5 TODO comments/blocks
# - sample.py: ~5 TODO comments/blocks
# - sample.sh: ~3 TODO comments/blocks
# - server.js: ~15 TODO comments/blocks
# - database.py: ~20 TODO comments/blocks
# - utils.rb: ~15 TODO comments/blocks
# Expected total: ~237 tasks (allowing some variance for blocks)

# Test minimum threshold (should be at least 220 tasks)
if [ "$total_tasks" -lt 220 ]; then
  echo "${RED}✗ Expected at least 220 tasks, got $total_tasks${NC}"
  FAILED=$((FAILED + 1))
else
  echo "${GREEN}✓ Task count looks good ($total_tasks tasks)${NC}"
  PASSED=$((PASSED + 1))
fi

# Verify status distribution
echo ""
echo "Verifying status distribution..."
todo_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'TODO';")
done_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'DONE';")
echo "TODO: $todo_count, DONE: $done_count"

# Most tasks should be TODO (from .todo files and code comments)
# Only large_todo.txt has DONE tasks (12 completed tasks)
assert_contains "$(test $todo_count -gt 200 && echo 'yes' || echo 'no')" "yes" "Should have >200 TODO tasks"
assert_contains "$(test $done_count -ge 10 && echo 'yes' || echo 'no')" "yes" "Should have >=10 DONE tasks"

# Verify priority distribution
echo ""
echo "Verifying priority distribution..."
priority_1_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE priority = 1;")
priority_2_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE priority = 2;")
priority_3_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE priority = 3;")
no_priority_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE priority IS NULL;")
echo "Priority 1: $priority_1_count, Priority 2: $priority_2_count, Priority 3: $priority_3_count, None: $no_priority_count"

# Most tasks from .todo and code won't have priority, only large_todo.txt has priorities
assert_contains "$(test $no_priority_count -gt 150 && echo 'yes' || echo 'no')" "yes" "Most tasks should have no priority"
assert_contains "$(test $priority_1_count -gt 0 && echo 'yes' || echo 'no')" "yes" "Should have some priority 1 tasks"

# Verify topics
echo ""
echo "Verifying topics..."
topic_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM topics;")
echo "Total topics: $topic_count"

# large_todo.txt has many topics: work, family, personal, devops, mobile, marketing, etc.
# Should have at least 20 unique topics
assert_contains "$(test $topic_count -ge 20 && echo 'yes' || echo 'no')" "yes" "Should have >=20 topics"

# Verify specific topics exist from large_todo.txt
assert_row_exists "topics" "topic = 'work'" "Should have 'work' topic"
assert_row_exists "topics" "topic = 'devops'" "Should have 'devops' topic"
assert_row_exists "topics" "topic = 'family'" "Should have 'family' topic"
assert_row_exists "topics" "topic = 'chapelShelvig'" "Should have 'chapelShelvig' topic"

# Verify tasks per topic
echo ""
echo "Verifying tasks per topic..."
work_task_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM task_topics tt JOIN topics t ON tt.topic_id = t.id WHERE t.topic = 'work';")
echo "Tasks tagged with 'work': $work_task_count"
assert_contains "$(test $work_task_count -gt 30 && echo 'yes' || echo 'no')" "yes" "Work topic should have >30 tasks"

# Verify file associations
echo ""
echo "Verifying file associations..."
file_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM files;")
echo "Total files tracked: $file_count"

# Should have all the fixture files: large_todo.txt, .todo files, code files
# Expected: 1 todo.txt + 5 .todo files + 6 code files = 12 files
assert_contains "$(test $file_count -ge 10 && echo 'yes' || echo 'no')" "yes" "Should have >=10 files tracked"

# Verify specific files exist
assert_row_exists "files" "path LIKE '%large_todo.txt'" "Should track large_todo.txt"
assert_row_exists "files" "path LIKE '%project_tasks.todo'" "Should track project_tasks.todo"
assert_row_exists "files" "path LIKE '%server.js'" "Should track server.js"
assert_row_exists "files" "path LIKE '%database.py'" "Should track database.py"

# Verify tasks have file associations
tasks_with_files=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE file_id IS NOT NULL;")
echo "Tasks with file associations: $tasks_with_files"
assert_equal "$total_tasks" "$tasks_with_files" "All tasks should be associated with a file"

# Test statistics output
echo ""
echo "Testing statistics output..."
stats_output=$(show_stats)
assert_contains "$stats_output" "Total Tasks:" "Stats should show total tasks"
assert_contains "$stats_output" "Status Counts:" "Stats should show status counts"
assert_contains "$stats_output" "Priority Counts:" "Stats should show priority counts"
assert_contains "$stats_output" "Topic Counts:" "Stats should show topic counts"

# Show final statistics
echo ""
echo "${BLUE}Final Statistics from All Sources:${NC}"
echo "=========================================="
show_stats

teardown_test

print_summary
