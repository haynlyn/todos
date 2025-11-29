# Test Fixtures Documentation

This document describes the test fixtures and expected outcomes when running tests.

## Fixture Files

### demo1.todo
**Location:** `tests/fixtures/demo1.todo`
**Format:** Simple `.todo` file with pipe-separated title and content
**Expected Results:**
- **Task Count:** 5 tasks
- **Tasks:**
  1. "Fix login bug" with content "Need to handle edge case when password is empty"
  2. "Add user profile page" (no content)
  3. "Update documentation" (no content)
  4. "Write unit tests for auth module" with content "Cover all edge cases"
  5. "Refactor database connection logic" (no content)

**When scanned with `build --from todo-files`:**
- Creates 5 tasks in database
- Each task linked to file entry for `demo1.todo`
- Line numbers captured (1-5)
- User: testuser (or specified user)
- Status: TODO (default)

### demo2.todo
**Location:** `tests/fixtures/demo2.todo`
**Format:** Simple `.todo` file with pipe-separated title and content
**Expected Results:**
- **Task Count:** 5 tasks
- **Tasks:**
  1. "High priority security patch"
  2. "Implement OAuth2 authentication" with content "Add support for Google and GitHub providers"
  3. "Design new dashboard layout"
  4. "Review pull requests from contributors" with content "Focus on security-related changes"
  5. "Optimize database queries for better performance"

**When scanned with `build --from todo-files`:**
- Creates 5 tasks in database
- Each task linked to file entry for `demo2.todo`
- Line numbers captured (1-5)

**Combined demo1.todo + demo2.todo:**
- Total tasks: 10
- Total files: 2

---

### sample.py
**Location:** `tests/fixtures/sample.py`
**Format:** Python source code with TODO comments and blocks
**Expected Results:**

**TODO Comments (single-line):**
1. Line ~7: "Add rate limiting to prevent brute force attacks"
2. Line ~10: "This is vulnerable to SQL injection"
3. Line ~13: "Hash password before comparison"
4. Line ~19: "Need to add retry logic for failed sends"

**TODO Blocks (`TODO: { }`):**
5. Lines ~22-26: Multi-line block about email error handling
   - Title: "Implement proper error handling for email failures"
   - Content: Full block content including all improvements

**TODOS.START/END Blocks:**
6. Lines ~30-34: User management improvements
   - Title: "Add method to bulk import users from CSV"
   - Content: All items in the block

**Other markers:**
- FIXME comments (counted as TODO)
- NOTE comments
- XXX comments
- HACK comments

**When scanned with `build --from all`:**
- Finds 10+ TODO-style items
- File associations created for `sample.py`
- Line numbers captured for each
- Different TODO markers (TODO, FIXME, NOTE, XXX, HACK) all treated as tasks

---

### sample.sh
**Location:** `tests/fixtures/sample.sh`
**Format:** Shell script with TODO comments and blocks
**Expected Results:**

**TODO Comments:**
1. Line ~4: "Add command-line argument parsing"
2. Line ~5: "Handle spaces in file paths properly"
3. Line ~8: "Need to add incremental backup support"

**TODO Blocks (`TODO: { }`):**
4. Lines ~12-15: Backup improvements
   - Multiple items about compression and rotation

**TODOS.START/END Blocks:**
5. Lines ~19-23: Deployment improvements
   - Health checks, rollback, notifications

**When scanned with `build --from all`:**
- Finds 8+ TODO-style items
- Shell script TODO formats recognized
- Both `#` and multi-line comment formats handled

---

### sample.c
**Location:** `tests/fixtures/sample.c`
**Format:** C source code with TODO comments and blocks
**Expected Results:**

**TODO Comments:**
1. Line ~6: "Add input validation for buffer overflow protection"
2. Line ~7: "Memory leak in error handling path"

**TODO Blocks (C-style `/* TODO: { } */`):**
3. Lines ~9-13: Error handling improvements
   - Multiple improvements listed

**TODOS.START/END Blocks:**
4. Lines ~19-23: Input processing improvements
   - Bounds checking, sanitization, tests

**Other markers:**
- NOTE, XXX, HACK, FIXME all captured

**When scanned with `build --from all`:**
- Finds 10+ TODO-style items
- C comment formats (`//` and `/* */`) both recognized
- Multi-line block comments parsed correctly

---

### todo.txt
**Location:** `tests/fixtures/todo.txt`
**Format:** Valid todo.txt format (see http://todotxt.org)
**Expected Results:**
- **Task Count:** 10 tasks
- **Task Breakdown:**

| # | Priority | Status | Created | Completed | Title | Topics | Due Date |
|---|----------|--------|---------|-----------|-------|--------|----------|
| 1 | A | TODO | 2024-01-15 | - | Call Mom | family, phone | - |
| 2 | - | TODO | 2024-01-14 | - | Review code changes | work, computer | - |
| 3 | B | TODO | 2024-01-16 | - | Buy groceries | personal, errands | 2024-01-20 |
| 4 | - | DONE | 2024-01-10 | 2024-01-18 | Fix authentication bug | work, computer | - |
| 5 | C | TODO | - | - | Write blog post about testing | blog, writing | - |
| 6 | - | TODO | - | - | Schedule dentist appointment | health, phone | 2024-02-01 |
| 7 | - | DONE | 2024-01-15 | 2024-01-17 | Deploy v2.0 to production | work, computer | - |
| 8 | - | TODO | - | - | Research new framework options | work, computer | - (has note) |
| 9 | A | TODO | - | - | Submit expense report | work, admin | 2024-01-25 |
| 10 | - | TODO | - | - | Plan vacation itinerary | personal, planning | - (has note) |

**Topics Created from @contexts and +projects:**
- family
- phone
- work
- computer
- personal
- errands
- blog
- writing
- health
- admin
- planning

**When imported with `import todo.txt`:**
- All 10 tasks created
- Priorities converted: (A)→1, (B)→2, (C)→3
- Completed tasks have both created_at and completed_at dates
- Topics automatically created and linked to tasks
- Due dates preserved with `due:YYYY-MM-DD` tag
- Notes stored in content field
- Task-topic relationships established in task_topics table

**When exported with `export output.txt --all`:**
- Recreates valid todo.txt format
- Priorities converted back: 1→(A), 2→(B), 3→(C)
- Completed tasks: `x 2024-01-18 2024-01-10 Task title`
- Topics exported as +topic
- Due dates as `due:2024-01-20`
- Notes as `note:"content text"`

**Round-trip Test:** import → export → import → verify
- Task count should remain 10
- All data should be preserved
- Topics should maintain relationships

---

## Test Database State After Fixture Processing

### After: `build --from all` on all fixtures

**Expected Database State:**
```
Tables populated:
├── tasks: 35-40 tasks (10 from .todo files, 25-30 from code comments/blocks)
├── files: 5 entries (demo1.todo, demo2.todo, sample.py, sample.sh, sample.c)
├── users: 1 (testuser)
├── topics: 0-5 (if any tasks are tagged)
├── task_topics: relationships as tagged
└── projects: 0 (unless explicitly created)
```

**Task Distribution:**
- demo1.todo: 5 tasks
- demo2.todo: 5 tasks
- sample.py: 8-10 tasks
- sample.sh: 6-8 tasks
- sample.c: 8-10 tasks

**File References:**
- All tasks have file_id linking to files table
- All tasks have line_start (and line_end for blocks)

### After: `import todo.txt`

**Expected Database State:**
```
Tables populated:
├── tasks: 10 tasks
├── files: 1 entry (todo.txt)
├── users: 1 (testuser)
├── topics: 11 topics (family, phone, work, computer, personal, errands, blog, writing, health, admin, planning)
├── task_topics: 20 relationships (each task has 2 topics on average)
└── user_topics: 0 (unless user subscribes)
```

**Task Fields:**
- 2 tasks with status='DONE'
- 8 tasks with status='TODO'
- 3 tasks with priorities (1, 2, 3)
- 2 tasks with completed_at dates
- 10 tasks with created_at dates (or current timestamp)
- 4 tasks with due_date values
- 2 tasks with content (from note: tags)

---

## Common Test Scenarios

### Scenario 1: Initialize Database + Scan All Fixtures
```bash
todos init
todos build --from all -d tests/fixtures
```

**Expected Outcome:**
- Database created with schema
- Current user added
- 35-40 tasks created
- 5 file entries
- Tasks distributed across files
- Mix of TODO/FIXME/NOTE/XXX/HACK markers captured

### Scenario 2: Import + Modify + Export
```bash
todos init
todos import tests/fixtures/todo.txt
todos create -t "New task" -p 1
todos export output.txt --all
```

**Expected Outcome:**
- 10 tasks from import
- 11 topics created
- 1 additional task created (total: 11)
- Export contains all 11 tasks
- All priorities preserved
- Topics included in export

### Scenario 3: Subscribe to Topics + Filter
```bash
todos init
todos import tests/fixtures/todo.txt
todos subscribe work
todos subscribe personal
todos list -t work -i
```

**Expected Outcome:**
- User subscribed to 'work' and 'personal'
- List shows only incomplete work tasks
- Should display 4-5 tasks (work-tagged incomplete tasks)

### Scenario 4: Create Project with Tasks
```bash
todos init
todos create -t "Task 1" -p 1
todos create -t "Task 2" -p 2
todos create -t "Task 3" -p 3
todos tag 1 urgent
todos tag 2 work
todos tag 3 personal
```

**Expected Outcome:**
- 3 tasks created
- 3 topics created (urgent, work, personal)
- 3 task-topic relationships
- Can list by each topic

---

## Test Assertions Reference

When writing tests, expect these counts:

| Fixture | Tasks | Files | Topics | Comments | Blocks |
|---------|-------|-------|--------|----------|--------|
| demo1.todo | 5 | 1 | 0 | 0 | 0 |
| demo2.todo | 5 | 1 | 0 | 0 | 0 |
| sample.py | 10 | 1 | 0 | 6 | 2 |
| sample.sh | 8 | 1 | 0 | 5 | 2 |
| sample.c | 10 | 1 | 0 | 6 | 2 |
| todo.txt | 10 | 1 | 11 | 0 | 0 |
| **TOTAL** | **48** | **6** | **11** | **17** | **6** |

## Notes

- Task counts are approximate due to variations in comment parsing
- All tests use temporary databases in `/tmp/todos_test_*.db`
- Tests clean up after themselves
- Fixtures are read-only and not modified by tests
- SQL escaping for special characters is currently a known limitation (tests document this)
- Some tests intentionally test error conditions and negative cases
