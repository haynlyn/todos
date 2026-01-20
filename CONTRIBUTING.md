# Contributing to todos

Thank you for your interest in contributing to `todos`! This guide will help you get started with development.

## Table of Contents

- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Makefile Targets](#makefile-targets)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Project Structure](#project-structure)

## Development Setup

### Prerequisites

**Required:**
- SQLite 3
- POSIX-compliant shell (sh, bash, zsh)
- Git

**Optional but recommended:**
- `shellcheck` - For linting shell scripts
- `shfmt` - For formatting shell scripts
- `entr` - For continuous testing

### Check Requirements

```bash
make requirements
```

This will show which tools you have installed and which are missing.

### Install Development Tools

**macOS:**
```bash
brew install shellcheck shfmt entr
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck entr
# shfmt requires manual installation or go install
go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

**Fedora:**
```bash
sudo dnf install ShellCheck entr
go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

### Clone and Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/todos.git
cd todos

# Install in development mode (uses symlinks)
make dev-install

# Verify installation
todos help
```

**Development mode** creates symlinks to your working directory, so changes to the code take effect immediately without reinstalling.

## Development Workflow

### Typical Development Cycle

1. **Make changes** to code in `lib/`, `bin/`, or `share/`
2. **Run linter** to check for issues: `make lint`
3. **Run tests** to ensure nothing broke: `make test`
4. **Format code** (optional): `make format`
5. **Commit** your changes

### Quick Commands

```bash
# Check your code before committing
make pre-commit

# Run full validation (lint + all tests)
make check

# Watch for changes and auto-test
make test-watch
```

### Working with Database Changes

When you're testing the `todos` tool itself and making database changes:

```bash
# Make changes using the todos command
todos create "Test feature"
todos update 1 -s DONE

# See what changed (optional)
todos diff

# Commit the database if testing collaborative features
git add .todos.db
git commit -m "Test: validate task completion workflow"
```

## Makefile Targets

The project uses Make to standardize common development tasks. Run `make help` or just `make` to see all available targets.

### Installation

| Target | Description |
|--------|-------------|
| `make install` | Install todos to `~/.local` (or custom `PREFIX`) |
| `make dev-install` | Install with symlinks for development |
| `make uninstall` | Remove installed files |
| `make reinstall` | Uninstall then install |

**Custom installation prefix:**
```bash
PREFIX=/usr/local make install
```

### Testing

| Target | Description |
|--------|-------------|
| `make test` | Run all tests (unit + integration) |
| `make test-unit` | Run only unit tests |
| `make test-integration` | Run only integration tests |
| `make test-verbose` | Run tests with verbose output |
| `make test-watch` | Continuously run tests on file changes (requires `entr`) |

**Examples:**
```bash
# Quick test during development
make test-unit

# Full test suite before committing
make test

# Debug failing tests
make test-verbose

# Continuous testing while coding
make test-watch
```

### Code Quality

| Target | Description |
|--------|-------------|
| `make lint` | Run shellcheck on all scripts |
| `make format` | Format all scripts with shfmt |
| `make format-check` | Check if scripts are properly formatted |
| `make check` | Run lint + all tests |
| `make validate` | Alias for `check` |

**Linting workflow:**
```bash
# Check for issues
make lint

# Auto-fix formatting
make format

# Verify everything passes
make check
```

### Cleanup

| Target | Description |
|--------|-------------|
| `make clean` | Remove test artifacts |
| `make clean-test` | Remove only test databases |
| `make distclean` | Full cleanup including installed files |

### Git Hooks

| Target | Description |
|--------|-------------|
| `make pre-commit` | Run pre-commit checks (lint + unit tests) |
| `make install-hooks` | Install git pre-commit hook |

**Install pre-commit hook:**
```bash
make install-hooks
```

This will automatically run `make pre-commit` before each git commit.

### Release

| Target | Description |
|--------|-------------|
| `make release` | Create release tarball |
| `make version` | Display version information |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | Display all available targets |
| `make requirements` | Check for required and optional tools |
| `make debug` | Display Makefile configuration |
| `make docs` | Validate documentation |

## Testing

### Test Philosophy

Tests mirror production workflows:
- Users are auto-created via `ensure_current_user()` (no test shortcuts)
- Tests use the same commands users would run
- No hidden/undocumented test-only features

See [tests/README.md](tests/README.md) for comprehensive testing documentation.

### Running Tests

```bash
# Run all tests
make test

# Run specific test category
make test-unit
make test-integration

# Run a specific test file
cd tests
./run_tests.sh --test unit/test_tasks.sh

# Verbose output for debugging
make test-verbose
```

### Writing Tests

**Test file location:**
- `tests/unit/` - Unit tests for individual functions
- `tests/integration/` - Integration tests for workflows

**Test file template:**
```bash
#!/bin/sh
# Test description

# Source test helpers
. "$(dirname "$0")/../test_helpers.sh"

test_function_name() {
  # Setup
  setup_test_env

  # Test
  result=$(todos command arg)

  # Assert
  assert_equals "expected" "$result"
}

# Run tests
run_test "Function name" test_function_name
```

**Best practices:**
- One test file per module
- Clear test names describing what is tested
- Clean up after tests (handled by `setup_test_env`)
- Test both success and failure cases

### Test Helpers

Available helpers in `tests/test_helpers.sh`:
- `setup_test_env` - Initialize clean test database
- `assert_equals` - Assert two values are equal
- `assert_contains` - Assert string contains substring
- `run_test` - Run a test function with reporting

## Code Style

### Shell Script Style

**POSIX compliance:**
- Use `#!/bin/sh` (not `#!/bin/bash`)
- Avoid bashisms (use shellcheck to detect)
- Use POSIX-compliant constructs

**Formatting (enforced by shfmt):**
- 2-space indentation
- Case indent enabled
- Function braces on same line

**Example:**
```bash
#!/bin/sh

my_function() {
  local var="value"

  if [ -n "$var" ]; then
    echo "Value: $var"
  fi

  case "$1" in
    option1)
      echo "Option 1"
      ;;
    option2)
      echo "Option 2"
      ;;
  esac
}
```

### Naming Conventions

- **Functions:** `snake_case` - `create_task()`, `list_tasks()`
- **Variables:** `UPPER_CASE` for constants, `snake_case` for locals
- **Files:** `snake_case.sh` - `tasks.sh`, `import_export.sh`

### Comments

- Use comments to explain **why**, not **what**
- Document non-obvious behavior
- Add TODO comments for future improvements
- Keep comments up to date with code

**Example:**
```bash
# Use transaction to ensure atomicity when creating task and file record
sql "BEGIN TRANSACTION;"
# ... transaction logic
sql "COMMIT;"
```

### Error Handling

- Always check command results: `if ! command; then`
- Use `set -e` in scripts that should fail fast
- Provide helpful error messages
- Exit with appropriate codes (0 = success, 1 = error)

**Example:**
```bash
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 not found" >&2
  echo "Install with: brew install sqlite3" >&2
  exit 1
fi
```

## Submitting Changes

### Before Submitting

1. **Run full validation:**
   ```bash
   make check
   ```

2. **Update documentation** if needed:
   - Update README.md for user-facing changes
   - Update CONTRIBUTING.md for development changes
   - Add/update comments in code

3. **Write tests** for new functionality:
   - Unit tests for new functions
   - Integration tests for workflows

4. **Format your code:**
   ```bash
   make format
   ```

### Creating a Pull Request

1. **Fork the repository** on GitHub

2. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** following the code style

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "Add feature: description"
   ```

   **Commit message format:**
   - Use imperative mood: "Add feature" not "Added feature"
   - First line: brief summary (50 chars or less)
   - Blank line, then detailed description if needed
   - Reference issues: "Fixes #123"

5. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request** on GitHub:
   - Describe what your changes do
   - Reference related issues
   - Explain testing performed

### PR Checklist

- [ ] Code follows style guidelines
- [ ] All tests pass (`make test`)
- [ ] Linting passes (`make lint`)
- [ ] New tests added for new functionality
- [ ] Documentation updated
- [ ] Commit messages are clear

## Project Structure

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
│   ├── uninstall_impl.sh  # Uninstall implementation
│   └── users.sh           # User management
├── share/
│   └── schema.sql         # Database schema
├── tests/
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   ├── fixtures/          # Test data
│   ├── test_helpers.sh    # Test utilities
│   └── run_tests.sh       # Test runner
├── install.sh             # Installation script
├── uninstall.sh           # Uninstallation script
├── Makefile               # Build automation
├── README.md              # User documentation
└── CONTRIBUTING.md        # This file
```

### Key Files

- **bin/todos** - Main entry point, parses commands and routes to modules
- **lib/common.sh** - Shared functions used across modules
- **lib/db.sh** - Database initialization and SQL helpers
- **lib/tasks.sh** - Core task management (create, list, update, delete)
- **share/schema.sql** - Database schema definition

### Adding a New Command

1. **Add function** to appropriate `lib/*.sh` file:
   ```bash
   # In lib/tasks.sh
   my_new_command() {
     # Implementation
   }
   ```

2. **Add command handler** in `bin/todos`:
   ```bash
   case "$1" in
     # ... existing commands
     my-command)
       shift
       my_new_command "$@"
       ;;
   esac
   ```

3. **Update help text** in `bin/todos`

4. **Write tests** in `tests/unit/test_tasks.sh`

5. **Update documentation** in README.md

## Questions?

- **Bug reports:** [GitHub Issues](https://github.com/yourusername/todos/issues)
- **Feature requests:** [GitHub Issues](https://github.com/yourusername/todos/issues)
- **Questions:** Open a discussion on GitHub

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
