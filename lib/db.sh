#!/bin/sh
# database management library

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"

init_db() {
  # Initialize database in current directory or specified path
  DB_PATH="$1"

  if [ -z "$DB_PATH" ]; then
    DB_PATH="$PWD/.todos.db"
  fi

  # Check if database already exists
  if [ -f "$DB_PATH" ]; then
    echo "Database already exists at: $DB_PATH"
    echo "Use 'todos flush' to reinitialize or 'todos delete' to remove it."
    return 1
  fi

  echo "Initializing database at: $DB_PATH"

  DB=$(realpath "$DB_PATH")
  mkdir -p "$(dirname "$DB")"

  # Find schema.sql - check installed location first, then dev location
  SCHEMA_PATH=""
  if [ -f "$HOME/.local/share/todos/schema.sql" ]; then
    SCHEMA_PATH="$HOME/.local/share/todos/schema.sql"
  elif [ -f "$LIBDIR/../share/schema.sql" ]; then
    SCHEMA_PATH="$LIBDIR/../share/schema.sql"
  else
    echo "Error: Cannot find schema.sql" >&2
    return 1
  fi

  sqlite3 "$DB" < "$SCHEMA_PATH"

  # Add initial user
  initial_user="$(get_calling_user)"
  sqlite3 "$DB" "INSERT INTO users (user, created_by) VALUES ('$initial_user', 'system');"

  echo "Created new database at $DB"
  echo "Initial user: $initial_user"

  echo ""
  echo "Next steps:"
  echo "  - Add .todos.db to git (commit it to share with team)"
  echo "  - Users will be auto-created on first command"
  echo "  - All todos commands will work from this directory or any subdirectory"
}

# NOTE: User management functions moved to lib/users.sh
# Use 'todos user' commands for user management

import_from_db() {
  # TODO: Implement database import functionality
  return 0
}

flush_db() {
  # Validate parameter
  if [ -z "$1" ]; then
    echo "Error: flush_db requires reinit parameter (true/false)" >&2
    return 1
  fi

  DB_PATH=$(get_db_path) || return 1

  if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database not found at $DB_PATH" >&2
    return 1
  fi

  echo "Database path: $DB_PATH"
  echo "Deleting database..."
  rm "$DB_PATH"

  if [ "$1" = 'true' ]; then
    echo "Rebuilding database..."
    init_db
  fi

  return 0
}
