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

  # Add initial admin user
  initial_user="$(get_calling_user)"
  sqlite3 "$DB" <<EOF
INSERT INTO users (user, role, created_by)
VALUES ('$initial_user', 'admin', 'system');

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('add_user', '$initial_user', 'system', 'Initial admin during todos init');
EOF

  echo "Created new database at $DB"
  echo "Initial admin: $initial_user"

  # Create .todosrc in current directory to mark project root
  cat > "$PWD/.todosrc" <<EOF
# Todos database configuration
DB=$DB
EOF
  echo "Created .todosrc in current directory"

  echo ""
  echo "Next steps:"
  echo "  - Add .todosrc and .todos.db to git (commit both)"
  echo "  - Users will be auto-created on first command"
}

# NOTE: User management functions moved to lib/users.sh
# Use 'todos admin user' commands for user management

import_from_db() {
  # TODO: Implement database import functionality
  return 0
}

flush_db() {
  DB_PATH=$(get_db_path)
  echo $DB_PATH
  
  if [ -e $DB_PATH ]; then
    echo "Deleting database."
    rm $DB_PATH
    if [ $1 = 'true' ]; then
      echo "Rebuilding database."
      init_db
    fi
    
  else
    echo "No database found - this should be moved further up. Don't allow any db operations if one doesn't exist."
  fi

  return 1
}
