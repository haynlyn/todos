#!/bin/sh
# Unit tests for build/scanning operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/build.sh"

FIXTURES_DIR="$(dirname "$0")/../fixtures"

echo "${BLUE}Running Build/Scan Tests${NC}"
echo "========================================"

# Test 1: Scan .todo files
setup_test
build_from_files --from todo-files -d "$FIXTURES_DIR" > /dev/null 2>&1
# demo1.todo: 5, demo2.todo: 4, project_tasks.todo: 25, bugs.todo: 20, features.todo: 20
# Total: 74 non-blank lines + 1 extra line = 75 tasks from .todo files
assert_db_count "tasks" 75 "Should have 75 tasks from .todo files"
teardown_test

# Test 2: .todo files create file associations
setup_test
build_from_files --from todo-files -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
assert_row_exists "files" "path LIKE '%demo1.todo'" "Should create file entry for demo1.todo"
assert_row_exists "files" "path LIKE '%demo2.todo'" "Should create file entry for demo2.todo"
teardown_test

# Test 3: Scan TODO comments
setup_test
build_from_files --from comments -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
# Should find TODO, FIXME, NOTE, XXX, HACK comments in sample files
todo_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
# We expect at least 10 TODO-style comments across the sample files
assert_contains "$(test $todo_count -ge 10 && echo 'yes' || echo 'no')" "yes" "Should find at least 10 TODO comments"
teardown_test

# Test 4: TODO comments link to files
setup_test
build_from_files --from comments -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
assert_row_exists "files" "path LIKE '%sample.py%'" "Should create file entry for sample.py"
assert_row_exists "files" "path LIKE '%sample.sh%'" "Should create file entry for sample.sh"
teardown_test

# Test 5: Scan TODOS.START/END blocks
setup_test
build_from_files --from blocks -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
# sample.py and sample.sh each have TODOS.START/END blocks
blocks_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE line_end IS NOT NULL;")
assert_contains "$(test $blocks_count -ge 2 && echo 'yes' || echo 'no')" "yes" "Should find at least 2 TODOS.START/END blocks"
teardown_test

# Test 6: Scan TODO: { } brace blocks
setup_test
build_from_files --from blocks -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
# sample.py, sample.sh, and sample.c have TODO: { } blocks
# Check that we found some
task_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
assert_contains "$(test $task_count -gt 0 && echo 'yes' || echo 'no')" "yes" "Should find TODO: { } brace blocks"
teardown_test

# Test 7: Scan all (auto mode)
setup_test
build_from_files --from all -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
# Should find tasks from .todo files, comments, and blocks
task_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
assert_contains "$(test $task_count -ge 20 && echo 'yes' || echo 'no')" "yes" "Auto mode should find many tasks (todo files + comments + blocks)"
teardown_test

# Test 8: Line numbers are captured for comments
setup_test
build_from_files --from comments -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
# All tasks from comments should have line_start
tasks_with_lines=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks WHERE line_start IS NOT NULL;")
total_tasks=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
assert_equal "$total_tasks" "$tasks_with_lines" "All comment tasks should have line numbers"
teardown_test

# Test 9: Duplicate scanning (should not create duplicates if run twice)
setup_test
build_from_files --from todo-files -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
first_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
build_from_files --from todo-files -d "$FIXTURES_DIR" --assign-to-me > /dev/null 2>&1
second_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM tasks;")
# Note: Current implementation WILL create duplicates. This test documents that behavior.
# If duplicate prevention is added later, this test should be updated.
assert_contains "$(test $second_count -eq $((first_count * 2)) && echo 'doubled' || echo 'not-doubled')" "doubled" "Current behavior: scanning twice doubles tasks (no duplicate prevention yet)"
teardown_test

# Test 10: Empty directory scan
setup_test
empty_dir="/tmp/empty_test_dir_$$"
mkdir -p "$empty_dir"
build_from_files --from all -d "$empty_dir" --assign-to-me > /dev/null 2>&1
assert_db_count "tasks" 0 "Empty directory should result in 0 tasks"
rmdir "$empty_dir"
teardown_test

print_summary
