#!/bin/sh
# Common utilities shared across all library files

find_project_root() {
  # Walk up directory tree looking for .todos.db file or .todos/ directory
  current_dir="$PWD"

  while [ "$current_dir" != "/" ]; do
    if [ -f "$current_dir/.todos.db" ] || [ -d "$current_dir/.todos" ]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Not found
  return 1
}

get_db_path() {
  # 1. Check if DB environment variable is set (for testing)
  if [ -n "$DB" ]; then
    echo "$DB"
    return 0
  fi

  # 2. Find project root (walks up looking for .todos.db or .todos/ directory)
  project_root=$(find_project_root)
  if [ -n "$project_root" ]; then
    echo "$project_root/.todos.db"
    return 0
  fi

  # 3. Not found - return error
  echo "Error: No todos database found." >&2
  echo "Run 'todos init' from your project root to create a database." >&2
  return 1
}

get_project_root() {
  project_root=$(find_project_root)
  if [ -n "$project_root" ]; then
    echo "$project_root"
  else
    echo "$PWD"
  fi
}

get_calling_user() {
  # Return the current user, with test environment support
  # Checks TODOS_TEST_USER first (for tests), then falls back to whoami
  echo "${TODOS_TEST_USER:-$(whoami)}"
}
