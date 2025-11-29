# Comprehensive Test Fixtures

This document describes the comprehensive test fixtures that cover all task origin formats.

## Overview

The test suite includes fixtures for all three task origin formats:
1. **todo.txt files** - Standard todo.txt format
2. **.todo files** - Simple line-based task files
3. **Code comments/blocks** - TODO comments and blocks in source code

**Total Tasks Across All Fixtures: 261**

## Fixture Files by Origin

### 1. Todo.txt Format (100 tasks)

#### `fixtures/large_todo.txt` - 100 tasks
Comprehensive todo.txt file with realistic task data covering multiple months.

**Content:**
- 100 tasks spanning from 2016 to 2024
- Priority distribution: A (9), B (7), C (6), None (78)
- Status: 15 DONE, 85 TODO
- 17 tasks with due dates
- 17 overdue tasks (as of 2025)
- 34 unique topics/contexts

**Topics covered:**
- work (62 tasks), devops (22), features (14), infrastructure (13)
- development, bugfix, documentation, performance, security
- marketing, mobile, analytics, testing, etc.

**Special tasks:**
- Line 11: Chapel shelving task (completed 2016-05-20, your custom task)

### 2. .todo Files (75 tasks)

#### `fixtures/demo1.todo` - 5 tasks
Simple tasks for basic testing.

#### `fixtures/demo2.todo` - 4 tasks
Additional basic tasks.

#### `fixtures/project_tasks.todo` - 25 tasks
Feature development and infrastructure tasks:
- User authentication, API documentation
- CI/CD, caching, admin dashboard
- Notifications, search, exports
- 2FA, audit logging, backups
- RBAC, API versioning, monitoring
- Webhooks, bulk operations
- Mobile responsiveness, validation
- i18n support, onboarding, analytics

#### `fixtures/bugs.todo` - 20 tasks
Bug fixes and issues:
- Memory leaks, race conditions
- Null pointer exceptions, timezone handling
- Pagination, CORS issues
- Validation errors, SQL injection
- Session timeouts, file uploads
- Cache invalidation, connection pools
- API inconsistencies, authentication
- Redirects, encoding, permissions

#### `fixtures/features.todo` - 20 tasks
New feature requests:
- Dark mode, real-time notifications
- Data visualization, PDF reports
- Collaborative editing, templates
- Keyboard shortcuts, drag-and-drop
- Advanced filtering, bookmarking
- Commenting system, tagging
- Favorites, sharing capabilities
- Activity feeds, comparison views
- Undo/redo, batch editing
- Auto-save, imports

### 3. Code Files with TODO Comments/Blocks (86 tasks)

#### `fixtures/sample.c` - ~5 tasks
C file with TODO comments.

#### `fixtures/sample.py` - ~5 tasks
Python file with TODO comments.

#### `fixtures/sample.sh` - ~3 tasks
Shell script with TODO comments.

#### `fixtures/server.js` - ~15 tasks
JavaScript/Node.js server with:
- TODO comments for error handling, logging, CORS
- FIXME for rate limiting, N+1 queries, password hashing
- XXX for security concerns
- TODOS.START/END blocks for OAuth providers
- TODO: { } brace blocks

**Topics covered:**
- Authentication, middleware, API design
- WebSocket, versioning, database cleanup

#### `fixtures/database.py` - ~20 tasks
Python database utilities with:
- TODO comments for connection pooling, replicas, SSL/TLS
- FIXME for error handling, constraints
- TODOS.START/END blocks for migrations
- TODO: { } brace blocks for validation

**Topics covered:**
- Connection management, migrations, backups
- Query optimization, monitoring, error handling

#### `fixtures/utils.rb` - ~15 tasks
Ruby utility functions with:
- TODO comments for validation, email queue, caching
- FIXME for timezone, SMTP errors, salt generation
- TODOS.START/END blocks for file processing
- TODO: { } brace blocks for string validation

**Topics covered:**
- Email, validation, file processing
- Password hashing, rate limiting, logging

## Test Coverage

### Comprehensive Build Test
`tests/integration/test_comprehensive_build.sh`

This integration test:
1. Imports all todo.txt fixtures
2. Builds from all .todo files
3. Scans all code files for TODO comments
4. Scans all code files for TODO blocks
5. Verifies expected metrics

**Assertions (20 total):**
- ✅ Total task count (261 tasks)
- ✅ Status distribution (246 TODO, 15 DONE)
- ✅ Priority distribution (239 no priority, 22 with priority)
- ✅ Topic counts (34 unique topics)
- ✅ File tracking (13 files)
- ✅ File associations (all 261 tasks linked to files)
- ✅ Statistics output validation

### Expected Metrics

```
Total Tasks: 261

Status Counts:
  DONE:        15 (6%)
  TODO:       246 (94%)

Priority Counts:
  Priority 1:   9
  Priority 2:   7
  Priority 3:   6
  None:       239 (92%)

Topics: 34 unique
  work:          62 tasks (most common)
  devops:        22 tasks
  features:      14 tasks
  infrastructure: 13 tasks
  development:    8 tasks
  bugfix:         7 tasks
  (and 28 more topics)

Date Information:
  Tasks with due dates: 17
  Overdue tasks:        17
  Completed tasks:      15

File Tracking:
  Total files:     13
  All tasks have file associations
```

## Running the Tests

### Run comprehensive test only:
```bash
cd tests
./integration/test_comprehensive_build.sh
```

### Run full test suite (12 test files):
```bash
cd tests
./run_tests.sh
```

### View statistics from fixtures:
```bash
cd /tmp/test_demo
todos init
todos import /path/to/todos/tests/fixtures/large_todo.txt
todos build --from all -d /path/to/todos/tests/fixtures
todos stats
```

## Fixture Design Principles

1. **Realistic Data**: Tasks represent real-world scenarios
2. **Variety**: Different priorities, statuses, dates, topics
3. **Coverage**: All task origin formats represented
4. **Scale**: Enough tasks (~260) to test performance
5. **Verification**: Expected metrics documented and tested

## Recent Changes

### Test Helper Improvements
- Renamed `assert_db_exists()` → `assert_row_exists()`
- Renamed `assert_db_not_exists()` → `assert_row_not_exists()`
- More accurate naming that reflects actual behavior (checking for rows, not DB existence)

### Schema Changes
- Made `content` required (todo.txt compatible)
- Made `title` optional (Jira-style)
- Content is now the primary task field

## Future Enhancements

Potential additions to fixtures:
- More code file formats (Java, Go, Rust, etc.)
- Multilingual TODO comments
- Edge cases: very long content, special characters
- Performance fixtures: 1000+ tasks for stress testing
- Malformed data for error handling tests
