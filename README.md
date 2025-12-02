# todos

A git-based, task-centric TODO management CLI tool with multi-user collaboration support.

## Overview

`todos` is a lightweight command-line task manager designed for teams that:
- Version control their tasks in git alongside their code
- Want automatic task discovery from code comments and TODO files
- Need multi-user task assignment and collaboration
- Prefer simple, POSIX-compliant shell scripts over complex frameworks
- Value task ownership transparency with git-based audit trails

**Philosophy:** Task-centric, not user-centric. Users are auto-created when they interact with tasks. All data lives in SQLite databases committed to git.

## Features

- **Task Management** - Create, update, delete, assign, and track tasks
- **Auto-Discovery** - Scan code for TODO comments, FIXME, NOTE markers
- **Multi-User** - Auto-created users, task reassignment, ownership tracking
- **Topics/Tags** - Organize tasks with topics, subscribe to areas of interest
- **Import/Export** - Compatible with todo.txt format
- **Git-Native** - Database committed to git, full history and audit trail
- **Project Support** - Group tasks into projects with shared users
- **Statistics** - View task counts by status, priority, user, topic
- **File Association** - Track which file/line each task relates to

## Requirements

- **SQLite 3** - For database storage
- **POSIX shell** - sh, bash, zsh, or compatible
- **Git** - For version control and collaboration (optional but recommended)

## Installation

### Quick Install

```bash
git clone https://github.com/yourusername/todos.git
cd todos
./install.sh
```

This installs to `~/.local/` by default (respects `PREFIX` environment variable).

**Custom installation location:**
```bash
# Install to /usr/local (system-wide, requires sudo)
sudo PREFIX=/usr/local ./install.sh

# Install to custom directory
PREFIX=$HOME/my-tools ./install.sh
```

### Installation Locations

| Component | Default Location | With PREFIX=/usr/local |
|-----------|-----------------|------------------------|
| Executable | `~/.local/bin/todos` | `/usr/local/bin/todos` |
| Libraries | `~/.local/lib/todos/` | `/usr/local/lib/todos/` |
| Schema | `~/.local/share/todos/` | `/usr/local/share/todos/` |
| Global Config | `~/.config/todos/config` | `~/.config/todos/config` |

**Note:** Global configuration uses `XDG_CONFIG_HOME` (defaults to `~/.config`), regardless of PREFIX.

### Manual Install

```bash
# Set installation prefix (default: ~/.local)
PREFIX="$HOME/.local"

# Copy files
cp -r lib "$PREFIX/lib/todos"
cp bin/todos "$PREFIX/bin/todos"
cp share/schema.sql "$PREFIX/share/todos/schema.sql"
chmod +x "$PREFIX/bin/todos"

# Add to PATH if needed
echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bashrc
source ~/.bashrc
```

### Verify Installation

```bash
todos help
```

## Quick Start

```bash
# 1. Initialize database in your project
cd /path/to/your/project
todos init

# 2. Create your first task
todos create "Fix authentication bug" -p 1 -d 2024-12-31

# 3. List tasks
todos list

# 4. Build tasks from code comments
todos build

# 5. View statistics
todos stats
```

## Basic Usage

### Task Operations

```bash
# Create a task
todos create "Task description" -t "Short title" -p 1 -d 2024-12-31

# List tasks
todos list                    # All tasks
todos list -i                 # Incomplete only
todos list -u alice           # Filter by user
todos list -t urgent          # Filter by topic

# Update a task
todos update 42 -s IN_PROGRESS -p 2

# Mark as complete
todos done 42

# Delete a task
todos delete 42

# Tag with topics
todos tag 42 urgent
todos tag 42 backend
```

### Task Ownership

```bash
# Reassign individual task
todos reassign 42 alice

# Reassign all tasks from one user to another
todos reassign-all --from bob --to alice

# Unassign a task
todos reassign 42 --unassign

# Bulk unassign
todos reassign-all --from bob --unassign
```

### User Management

```bash
# List users (shows task counts)
todos user list

# Remove user (only if 0 tasks)
todos user remove alice

# Clean up all users with 0 tasks
todos user prune

# Advanced/hidden commands (see `todos user --help`)
todos user add alice          # Manual creation (prefer auto-creation)
todos user del alice          # Unsafe deletion (prefer `remove`)
```

**Note:** Users are auto-created when they run commands. Manual user management is rarely needed.

### Topics

```bash
# Subscribe to topics
todos subscribe backend
todos subscribe urgent

# Unsubscribe
todos unsubscribe urgent

# List topics
todos topics              # Your subscriptions
todos topics --all        # All topics with stats
```

### Import/Export

```bash
# Import from todo.txt format
todos import tasks.txt

# Export all tasks
todos export output.txt -a

# Export only completed
todos export done.txt -d

# Export only incomplete
todos export active.txt -i
```

### Build from Files

```bash
# Auto-scan for TODOs in code
todos build                           # Scans all files
todos build --from comments           # Only code comments
todos build --from todo-files         # Only .todo files
todos build -d ./src                  # Specific directory
todos build --assign-to-me            # Assign discovered tasks to you
```

## File Formats

### .todo Files

Simple line-based format for standalone task files:

```
Task description | Optional additional details
Another task
Task with priority (A) Buy groceries
```

**Features:**
- One task per line
- Optional `|` separator for title and content
- Optional `(A)` - `(Z)` priority prefix
- Place anywhere in your project (e.g., `docs/backlog.todo`)

**Example (`project.todo`):**
```
Fix login bug | Handle edge case when password is empty
Add user profile page
Update documentation
(A) Write unit tests for auth module | Cover all edge cases
Refactor database connection logic
```

### todo.txt Format

Compatible with the [todo.txt](http://todotxt.org/) specification:

```
(A) 2024-01-15 Call Mom +family @phone
2024-01-14 Review code changes +work @computer
(B) Buy groceries +personal @errands due:2024-01-20
x 2024-01-18 2024-01-10 Fix bug +work @computer
```

**Format:**
- `(A)-(Z)` - Priority (optional)
- `YYYY-MM-DD` - Creation date (optional)
- `+project` - Project tags (converted to topics)
- `@context` - Context tags (converted to topics)
- `due:YYYY-MM-DD` - Due date
- `note:"text"` - Additional notes
- `x YYYY-MM-DD` - Completion marker and date

### Code Comments

`todos` automatically discovers tasks in code comments:

**Supported formats:**

```python
# TODO: Fix this edge case
# FIXME: Memory leak in loop
# NOTE: Consider refactoring

# TODO: {
#   This is a multi-line TODO block
#   with detailed description
# }

# TODOS.START
# - First task
# - Second task
# - Third task
# TODOS.END
```

**Languages supported:**
- Python, JavaScript, Shell, Ruby, etc. (`#` comments)
- C, C++, Java, Go (`//` and `/* */` comments)
- HTML, XML (`<!-- -->` comments)
- And more (any line-comment syntax)

## Project Structure

```
your-project/
├── .todos.db              # SQLite database (commit to git)
├── .todos/
│   └── config             # Project-local config (optional, can be committed)
├── docs/
│   └── backlog.todo       # Standalone task file
└── src/
    ├── main.py            # Code with TODO comments
    └── utils.py
```

## Testing

Run the full test suite:

```bash
cd tests
./run_tests.sh
```

Run specific test categories:

```bash
./run_tests.sh --unit          # Unit tests only
./run_tests.sh --integration   # Integration tests only
./run_tests.sh --test test_tasks.sh  # Specific test file
```

**Test Philosophy:**
- Tests mirror production workflows
- User creation via auto-creation mechanism (`ensure_current_user()`)
- No test-only SQL shortcuts
- Hidden commands exist but are untested (by design)

See [tests/README.md](tests/README.md) for complete testing documentation.

## Documentation

For detailed testing documentation, see:
- **[tests/README.md](tests/README.md)** - Testing philosophy, test structure, writing tests, running tests

### Quick References

**Get help:**
```bash
todos help                # Full command reference
todos user --help         # User commands (including hidden ones)
```

**Configuration:**

Two-level configuration system:
- **Global**: `${XDG_CONFIG_HOME:-~/.config}/todos/config` - Your defaults across all projects
- **Project-local**: `$PROJECT_ROOT/.todos/config` - Overrides for specific projects

```bash
# Set global default priority
todos config set --global create.default_priority 3

# Override for this critical project
todos config set create.default_priority 1

# View effective configuration
todos config list

# Get specific value
todos config get create.default_priority
```

See [Configuration](#configuration) section below for complete details.

## User Management Philosophy

**Task-centric, not user-centric:**

`todos` takes a task-centric approach where users exist only as metadata on tasks. Instead of managing users directly, you manage task ownership.

### Auto-Creation

Users are automatically created when they:
- Initialize a database: `todos init`
- Run any task command: `todos create`, `todos list`, etc.
- Get assigned tasks: `todos reassign <task-id> <username>`
- Subscribe to topics: `todos subscribe <topic>`

**Example:**
```bash
# Alice initializes the database
alice$ todos init        # User 'alice' auto-created

# Bob runs his first command
bob$ todos list          # User 'bob' auto-created

# Alice assigns task to Charlie (doesn't exist yet)
alice$ todos reassign 1 charlie
Created new user: charlie  # User 'charlie' auto-created
```

### Core Commands

**Task ownership (primary interface):**
```bash
# Reassign individual task
todos reassign 42 alice

# Move all tasks from one user to another
todos reassign-all --from bob --to alice

# Unassign tasks
todos reassign 42 --unassign
todos reassign-all --from bob --unassign
```

**User cleanup (safe operations):**
```bash
# List users with task counts
todos user list

# Remove user (only if 0 tasks)
todos user remove alice

# Remove all users with 0 tasks
todos user prune
```

### Common Workflows

**User leaves project:**
```bash
# Reassign all their tasks
todos reassign-all --from bob --to alice

# Remove empty user record
todos user remove bob

# Commit to git
git add .todos.db
git commit -m "Reassign bob's tasks to alice; remove bob"
```

**Fix username typo:**
```bash
# Reassign tasks to correct username
todos reassign-all --from alcie --to alice

# Remove typo user
todos user remove alcie
```

### Hidden Commands (Advanced)

For edge cases and testing only (access via `todos user --help`):
- `user add <username>` - Manual user creation (prefer auto-creation)
- `user del <username>` - Unsafe deletion allowing users with tasks (prefer `user remove`)

### Security Model

`todos` has **no built-in permission system**. Security is enforced via:
- **GitHub permissions** - Who can merge PRs
- **Code review** - Manual inspection of changes
- **GitHub Actions** - Automated validation of user table changes
- **Branch protection** - Prevent direct pushes
- **Git history** - Complete audit trail

See the GitHub Collaboration section below for enforcing admin approval of user changes.

## GitHub Collaboration

### Basic Workflow

1. **Initialize** in your repository:
   ```bash
   todos init
   git add .todos.db
   git commit -m "Initialize todos database"
   git push
   ```

2. **Team members clone and work:**
   ```bash
   git clone your-repo
   cd your-repo
   todos list              # Auto-creates their user
   todos create "My task"  # Creates task owned by them
   git add .todos.db
   git commit -m "Add task: implement feature X"
   git push
   ```

3. **User management changes** (requires admin approval):
   ```bash
   # Any contributor can run these locally
   todos reassign-all --from alice --to bob
   todos user remove alice

   # Create PR for admin review
   git checkout -b reassign-alice-to-bob
   git add .todos.db
   git commit -m "Reassign alice's tasks to bob; remove alice"
   git push origin reassign-alice-to-bob
   # Create PR - requires admin approval
   ```

### GitHub Actions Validation

**IMPORTANT:** Changes to the `users` table in `.todos.db` **must only be approved and merged by repository administrators**.

#### 1. Create Validation Script

Create `.github/scripts/validate_user_changes.sh`:

```bash
#!/bin/bash
# Validates user table changes

set -e

DB_FILE=".todos.db"

if [ ! -f "$DB_FILE" ]; then
  echo "No database found"
  exit 0
fi

# Check if database was modified
if ! git diff --name-only HEAD^ HEAD | grep -q "^\.todos\.db$"; then
  echo "✓ Database not modified"
  exit 0
fi

echo "✓ Database modified, checking user table..."

# Extract users table from current and previous commits
sqlite3 "$DB_FILE" "SELECT user FROM users ORDER BY user;" > /tmp/users_current.txt

git show HEAD^:.todos.db > /tmp/todos_prev.db 2>/dev/null || {
  echo "✓ Initial commit"
  exit 0
}
sqlite3 /tmp/todos_prev.db "SELECT user FROM users ORDER BY user;" > /tmp/users_prev.txt

# Show diff
if diff -u /tmp/users_prev.txt /tmp/users_current.txt > /tmp/users_diff.txt; then
  echo "✓ No changes to users table"
else
  echo "⚠️  Detected changes to users table:"
  cat /tmp/users_diff.txt
  echo ""
  echo "Ensure changes are authorized by repository admin"
fi

# Verify no duplicates
duplicates=$(sqlite3 "$DB_FILE" "SELECT user, COUNT(*) FROM users GROUP BY user HAVING COUNT(*) > 1;")
if [ -n "$duplicates" ]; then
  echo "❌ ERROR: Duplicate users found"
  exit 1
fi

echo "✓ Validation passed"
rm -f /tmp/users_*.txt /tmp/todos_prev.db
exit 0
```

Make executable:
```bash
chmod +x .github/scripts/validate_user_changes.sh
```

#### 2. Create GitHub Actions Workflow

Create `.github/workflows/validate-users.yml`:

```yaml
name: Validate User Changes

on:
  pull_request:
    paths:
      - '.todos.db'
  push:
    branches:
      - main
    paths:
      - '.todos.db'

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Install SQLite
        run: sudo apt-get update && sudo apt-get install -y sqlite3

      - name: Validate user table
        run: bash .github/scripts/validate_user_changes.sh

      - name: Verify database integrity
        run: |
          sqlite3 .todos.db "PRAGMA integrity_check;" | grep -q "ok" || {
            echo "❌ Database integrity check failed"
            exit 1
          }
          echo "✓ Database integrity OK"
```

#### 3. Configure CODEOWNERS

Create `.github/CODEOWNERS`:

```
# Require admin approval for database changes
/.todos.db @org/admins

# Or specific admin users:
# /.todos.db @alice @bob
```

**How this works:**
- PRs modifying `.todos.db` automatically request review from admins
- PR cannot be merged until an admin approves
- Combined with branch protection, enforces admin-only approval

#### 4. Configure Branch Protection

In GitHub repository settings (**Settings** → **Branches**):

1. Add branch protection rule for `main`:
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date
   - ✅ Select: `validate` (the GitHub Actions job)
   - ✅ Require review from Code Owners
   - ✅ Require pull request before merging
   - ✅ Do not allow bypassing settings

### Admin Review Workflow

When reviewing a PR that modifies `.todos.db`:

```bash
# 1. Check out the PR
gh pr checkout 123

# 2. Inspect user table changes
sqlite3 .todos.db "SELECT * FROM users;"

# 3. View the diff
git show HEAD^:.todos.db > /tmp/prev.db
sqlite3 /tmp/prev.db "SELECT * FROM users;" > /tmp/prev_users.txt
sqlite3 .todos.db "SELECT * FROM users;" > /tmp/curr_users.txt
diff -u /tmp/prev_users.txt /tmp/curr_users.txt

# 4. Verify changes match PR description
# - Review GitHub Actions output
# - Ensure changes are authorized

# 5. Approve and merge (admins only)
gh pr review 123 --approve
gh pr merge 123
```

### Git-Based Audit Trail

All user changes are tracked in git history. Query the audit trail:

```bash
# View all database changes
git log -p -- .todos.db

# Export users at each commit
for commit in $(git log --format=%H -- .todos.db); do
  echo "=== Commit: $commit ==="
  git show $commit:.todos.db > /tmp/db.db 2>/dev/null
  sqlite3 /tmp/db.db "SELECT user, created_at FROM users;" 2>/dev/null
done
```

**Benefits:**
- Zero database overhead (no audit table needed)
- Complete history preserved in git
- Standard git commands for querying
- Immutable audit trail

## Configuration

### Configuration Hierarchy

`todos` uses a two-level configuration system:

1. **Global** (`${XDG_CONFIG_HOME:-~/.config}/todos/config`) - Your personal defaults across all projects
2. **Project-local** (`$PROJECT_ROOT/.todos/config`) - Project-specific overrides

Project-local settings take precedence over global settings.

**Note:** Global configuration respects `XDG_CONFIG_HOME` environment variable (defaults to `~/.config`).

### Supported Settings

#### List Settings

```bash
list.default_sort           # Default sort field: priority, due_date, created_at
list.show_completed         # Show completed tasks by default: true/false
```

#### Create Settings

```bash
create.default_priority     # Default priority for new tasks: 1-26 (1=A, 2=B, ...)
create.default_status       # Default status: TODO, IN_PROGRESS, DONE
create.auto_assign_to_me    # Auto-assign created tasks to you: true/false
```

#### Build Settings

```bash
build.auto_assign           # Auto-assign discovered tasks to you: true/false
build.scan_paths            # Default paths to scan: src,lib,docs
build.default_from          # Default scan mode: auto, comments, todo-files, all
```

### Usage Examples

**Global configuration** (applies to all projects):

```bash
# Set your personal defaults
todos config set --global create.default_priority 3
todos config set --global create.auto_assign_to_me true
todos config set --global list.default_sort priority
todos config set --global build.auto_assign true
```

**Project-specific configuration** (overrides global for this project):

```bash
# Critical project needs higher default priority
cd ~/projects/production-backend
todos config set create.default_priority 1

# Different scan paths for this project
todos config set build.scan_paths src,internal,cmd
```

**View configuration**:

```bash
# See all configs with hierarchy
todos config list

# Get specific value (returns effective value after merge)
todos config get create.default_priority

# Unset project-local config (reverts to global)
todos config unset create.default_priority

# Unset global config
todos config unset --global create.default_priority
```

### Configuration Files

**Global config** (`${XDG_CONFIG_HOME:-~/.config}/todos/config`):
```ini
create.default_priority=3
create.auto_assign_to_me=true
list.default_sort=priority
build.auto_assign=true
```

**Project-local config** (`$PROJECT_ROOT/.todos/config`):
```ini
# Override for this critical project
create.default_priority=1
build.scan_paths=src,internal
```

**Note:** Configuration files are simple `key=value` format. Project-local config can be committed to git to share team conventions, or gitignored for personal overrides.

### Display Configuration (Coming Soon)

Display-related configuration (colors, date formats, output formats) is planned for future releases. See `BACKLOG.todo` for details.

## Database Schema

The SQLite database contains:

- `tasks` - Task content, status, priority, dates, file association
- `users` - User records (auto-created)
- `topics` - Task topics/tags
- `files` - File paths for task association
- `projects` - Project groupings
- `task_topics` - Many-to-many task-topic relationships
- `user_topics` - User topic subscriptions
- `project_tasks` - Project-task associations
- `project_users` - Project-user associations

Schema location: `share/schema.sql`

## Uninstallation

```bash
todos uninstall            # Interactive uninstall
todos uninstall --dry-run  # Preview what would be removed
```

This removes:
- `~/.local/bin/todos`
- `~/.local/lib/todos/`
- `~/.local/share/todos/`

**Note:** Project databases (`.todos.db`) are NOT removed - manage those manually.

## Development

### Project Layout

```
todos/
├── bin/
│   └── todos              # Main executable
├── lib/
│   ├── build.sh           # Build/scanning logic
│   ├── common.sh          # Shared utilities
│   ├── config.sh          # Configuration management
│   ├── db.sh              # Database operations
│   ├── import_export.sh   # Import/export logic
│   ├── stats.sh           # Statistics
│   ├── tasks.sh           # Task CRUD operations
│   ├── topics.sh          # Topic management
│   └── users.sh           # User management
├── share/
│   └── schema.sql         # Database schema
├── tests/
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   ├── fixtures/          # Test data
│   └── run_tests.sh       # Test runner
├── install.sh             # Installation script
└── README.md              # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass: `cd tests && ./run_tests.sh`
5. Update documentation
6. Submit a pull request

**Code style:**
- POSIX-compliant shell scripts
- Use `shellcheck` for linting
- Follow existing patterns in codebase
- Write tests that mirror production usage

## License

[Specify your license here]

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/todos/issues)
- **Documentation:** See `docs/` directory and inline help (`todos help`)
- **Questions:** Open a discussion on GitHub

## Acknowledgments

- Inspired by [todo.txt](http://todotxt.org/)
- Built with SQLite and POSIX shell
- Designed for git-native workflows
