#!/bin/sh
# Common utilities shared across all library files

find_project_root() {
  # Walk up directory tree looking for .todos.db or .todosrc
  current_dir="$PWD"

  while [ "$current_dir" != "/" ]; do
    if [ -f "$current_dir/.todos.db" ] || [ -f "$current_dir/.todosrc" ]; then
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

  # 2. Check for .todosrc in current directory or parents
  project_root=$(find_project_root)
  if [ -n "$project_root" ]; then
    if [ -f "$project_root/.todosrc" ]; then
      . "$project_root/.todosrc"
      echo "$DB"
      return 0
    fi
    # Found .todos.db directly
    if [ -f "$project_root/.todos.db" ]; then
      echo "$project_root/.todos.db"
      return 0
    fi
  fi

  # 3. Check global config
  if [ -f "$HOME/.config/todos/config" ]; then
    . "$HOME/.config/todos/config"
    if [ -n "$DB" ]; then
      echo "$DB"
      return 0
    fi
  fi

  # 4. Check for .todos.db in current directory
  if [ -f "$PWD/.todos.db" ]; then
    echo "$PWD/.todos.db"
    return 0
  fi

  # 5. Not found - return error
  echo "Error: No todos database found." >&2
  echo "Run 'todos init' to create a new database in this directory." >&2
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
