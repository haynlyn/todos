# Todos Test Suite

Comprehensive test suite for the todos project, including unit tests, integration tests, and test fixtures.

## Quick Start

Run all tests:
```bash
./run_tests.sh
```

Run only unit tests:
```bash
./run_tests.sh --unit
```

Run only integration tests:
```bash
./run_tests.sh --integration
```

Run a specific test file:
```bash
./run_tests.sh --test test_tasks.sh
```

Run with verbose output:
```bash
./run_tests.sh --verbose
```

## Test Structure

```
tests/
├── run_tests.sh           # Test runner
├── test_helpers.sh        # Test framework and assertion helpers
├── fixtures/              # Test data and sample files
│   ├── demo1.todo         # Simple task list
│   ├── demo2.todo         # Tasks with priorities
│   ├── sample.py          # Python code with TODOs
│   ├── sample.sh          # Shell script with TODOs
│   ├── sample.c           # C code with TODOS blocks
│   └── todo.txt           # Valid todo.txt format file
├── unit/                  # Unit tests
│   ├── test_db.sh         # Database operations
│   ├── test_tasks.sh      # Task CRUD operations
│   ├── test_topics.sh     # Topic management
│   ├── test_import_export.sh  # Import/export functionality
│   ├── test_build.sh      # Build/scanning operations
│   ├── test_config.sh     # Configuration management (23 tests)
│   └── test_stats.sh      # Statistics
└── integration/           # Integration tests
    ├── test_workflow.sh   # Complete user workflows
    ├── test_complex_queries.sh  # Complex query combinations
    ├── test_state_transitions.sh  # Task lifecycle
    └── test_edge_cases.sh # Error handling and edge cases
```

## Test Categories

### Unit Tests

**test_db.sh** - Database Management
- Database initialization
- User add/delete operations
- Schema validation
- Relationship cleanup

**test_tasks.sh** - Task Operations
- Create tasks with various field combinations
- Delete by ID and title
- Update multiple fields
- Priority, deadline, status management
- Special character and Unicode handling
- SQL injection prevention
- List and filter operations

**test_topics.sh** - Topic Management
- Subscribe/unsubscribe to topics
- Duplicate subscription handling
- Orphaned topic detection
- List topics for users

**test_import_export.sh** - Import/Export
- Import todo.txt format
- Export with filters (all, done, incomplete)
- Priority conversion (A-Z ↔ 1-26)
- Completion date handling
- Due date tags
- Topic creation from @context and +project
- Round-trip testing
- Note/content tags

**test_build.sh** - Build/Scanning
- Scan .todo files
- Scan TODO/FIXME/NOTE comments
- Scan TODOS.START/END blocks
- Scan TODO: { } brace blocks
- File association tracking
- Line number capture

**test_config.sh** - Configuration Management
- Global and project-local config hierarchy
- XDG Base Directory compliance (global config at `~/.config/todos/config`)
- Set/get/unset config values (--global and --project scopes)
- Update existing values without duplication
- Project-local config overrides global config
- Fallback to global when project not set
- Unset project reveals global value
- Directory creation (both global and project-local)
- Multiple config entries in same file
- Preserve other keys on unset
- get_config_or_default helper function
- Handle special characters (spaces, dots, equals signs, slashes)
- Handle namespaced keys (e.g., list.default_sort)
- Non-existent key error handling

### Integration Tests

**test_workflow.sh** - User Workflows
- Complete task lifecycle (init → create → tag → list → export)
- Build from fixtures → subscribe → filter
- Multi-user collaboration
- Import → modify → export
- Topic subscription workflows

**test_complex_queries.sh** - Complex Queries
- Multiple filter combinations (user + topic + status)
- Late tasks detection
- Tasks with multiple topics
- Sorting variations
- Filter by file
- Priority range filtering
- Combined filters

**test_state_transitions.sh** - State Management
- Task lifecycle: TODO → IN_PROGRESS → DONE
- Completion date handling
- Priority changes over time
- Updating completed tasks
- Reverting task status
- Updated_at timestamp tracking

**test_edge_cases.sh** - Edge Cases
- Missing required fields
- Non-existent resource operations
- Very long content
- Invalid date formats
- Special characters
- Empty imports
- Malformed input
- Maximum/negative values
- Concurrent operations
- Duplicate titles
- Empty exports

## Test Framework

The test framework (`test_helpers.sh`) provides:

### Setup/Teardown
- `setup_test()` - Creates temporary test database
- `teardown_test()` - Cleans up test database

### Assertions
- `assert_equal expected actual message`
- `assert_not_equal not_expected actual message`
- `assert_contains haystack needle message`
- `assert_not_contains haystack needle message`
- `assert_db_count table expected_count message`
- `assert_db_exists table where_clause message`
- `assert_db_not_exists table where_clause message`
- `assert_file_exists file_path message`

### Reporting
- Color-coded output (green ✓ for pass, red ✗ for fail)
- Test counter tracking
- Summary reporting with `print_summary()`

### User Creation for Tests

**Philosophy: Tests mirror production workflows**

Tests create users using the same auto-creation mechanisms as production code:

```bash
# Create test user using production pathway
create_test_user "alice"

# This internally calls ensure_current_user() with TODOS_TEST_USER="alice"
# Same code path as production when a new user interacts with the system
```

**Available functions:**
- `create_test_user "username"` - **Recommended:** Uses production auto-creation via `ensure_current_user()`
- `add_test_user "username"` - Legacy alias (calls `create_test_user()`)

**Why this matters:**
- Tests validate actual production code paths
- Ensures auto-creation logic is thoroughly tested
- No test-only SQL shortcuts that bypass business logic
- Hidden commands (`user add`/`user del`) exist for edge cases but tests use auto-creation

**Example:**
```bash
# Test multi-user scenario
setup_test
create_test_user "alice"  # Uses ensure_current_user()
create_test_user "bob"    # Uses ensure_current_user()

# Now alice and bob exist via the same mechanism as production
alice_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'alice';")
bob_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'bob';")
```

## Test Data

### Fixtures

**demo1.todo** - 5 simple tasks with descriptions
**demo2.todo** - 5 tasks with priorities and deadlines
**sample.py** - Python code with 10+ TODO comments and blocks
**sample.sh** - Shell script with TODO comments and blocks
**sample.c** - C code with various TODO formats
**todo.txt** - 10 tasks in valid todo.txt format with priorities, dates, contexts, and projects

## Writing New Tests

1. Create test file in appropriate directory (`unit/` or `integration/`)
2. Source the test helpers:
   ```bash
   . "$(dirname "$0")/../test_helpers.sh"
   ```
3. Load required libraries:
   ```bash
   LIBDIR=$(get_lib_path)
   . "$LIBDIR/tasks.sh"
   ```
4. Write test cases using setup/teardown pattern:
   ```bash
   setup_test
   # Your test code here
   assert_equal "expected" "actual" "Test description"
   teardown_test
   ```
5. Call `print_summary` at the end
6. Make test file executable: `chmod +x test_file.sh`

## CI/CD Integration

The test runner returns:
- Exit code 0 if all tests pass
- Exit code 1 if any tests fail

Example GitHub Actions usage:
```yaml
- name: Run tests
  run: cd tests && ./run_tests.sh
```

## Notes

- All tests use temporary databases in `/tmp/todos_test_*.db`
- Tests are isolated and don't affect your actual todos database
- **Tests mirror production workflows** - User creation uses `ensure_current_user()`, not SQL shortcuts
- Hidden commands (`user add`/`user del`) exist for edge cases but normal tests use auto-creation
- Some tests document current behavior that may be enhanced later
- Tests are POSIX-compliant shell scripts

## Hidden Commands

While `todos user add` and `todos user del` exist as hidden/advanced commands:

- ⚠️ **Not tested by automated test suite** - These commands are simple wrappers around SQL but are not covered by tests
- 🎯 **Tests use production pathways** - Normal tests use `create_test_user()` which calls `ensure_current_user()`
- 💡 **By design** - Testing auto-creation validates the recommended workflow; hidden commands are for edge cases only

**In test code:**
- ✅ **Use:** `create_test_user()` which calls `ensure_current_user()`
- ❌ **Avoid:** Direct SQL inserts or hidden commands (`user add`/`user del`)
- 💡 **Why:** Tests should validate the same code paths users will experience

**Hidden commands are documented via:**
```bash
todos user --help  # Shows all commands including advanced/hidden ones
```

**Rationale for not testing hidden commands:**
- They're intentionally discouraged from normal use
- Testing auto-creation (the recommended path) is more valuable
- Simple SQL wrappers with minimal logic
- Edge case/admin usage doesn't warrant full test coverage

See the "User Management Philosophy" section in the main README.md for complete documentation on the user management philosophy and workflows.
