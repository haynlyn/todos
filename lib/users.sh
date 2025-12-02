#!/bin/sh
# User management functions

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"

# NOTE: init_users_db() has been removed - users are now initialized in lib/db.sh init_db()

# Ensure current user exists in database
ensure_current_user() {
  # Use TODOS_TEST_USER for testing, otherwise whoami
  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path) || return 1

  # Check if database exists
  if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database not found. Run 'todos init' first." >&2
    return 1
  fi

  # Check if user exists
  user_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE user = '$current_user';")

  if [ "$user_exists" -eq 0 ]; then
    # Auto-create user
    sqlite3 "$DB_PATH" "INSERT INTO users (user, created_by) VALUES ('$current_user', '$current_user');"
    echo "Created user: $current_user"
  fi
}

# Get current user's ID
get_current_user_id() {
  # Use TODOS_TEST_USER for testing, otherwise whoami
  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path) || return 1

  sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$current_user';"
}

# Remove a user from the database (SAFE: only if user has 0 tasks)
remove_user() {
  target_user="$1"

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    echo "Usage: todos user remove <username>" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path) || return 1

  # Check if user exists
  user_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -eq 0 ]; then
    echo "Error: User '$target_user' not found" >&2
    return 1
  fi

  # Check if user has any tasks
  user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$target_user';")
  task_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE user_id = $user_id;")

  if [ "$task_count" -gt 0 ]; then
    echo "Error: Cannot remove user '$target_user' - they own $task_count task(s)" >&2
    echo "Reassign their tasks first:" >&2
    echo "  todos reassign-all --from $target_user --to <new-user>" >&2
    return 1
  fi

  # Prevent deleting yourself
  if [ "$target_user" = "$current_user" ]; then
    echo "Error: Cannot remove your own user account" >&2
    return 1
  fi

  # Delete user
  sqlite3 "$DB_PATH" "DELETE FROM users WHERE user = '$target_user';"

  echo "Removed user: $target_user"
  echo ""
  echo "⚠️  Remember to commit .todos.db to share this change"
}

# Prune all users with 0 tasks
prune_users() {
  DB_PATH=$(get_db_path) || return 1
  current_user="$(get_calling_user)"

  # Find users with 0 tasks (excluding current user)
  empty_users=$(sqlite3 "$DB_PATH" "
    SELECT u.user
    FROM users u
    LEFT JOIN tasks t ON u.id = t.user_id
    WHERE u.user != '$current_user'
    GROUP BY u.id, u.user
    HAVING COUNT(t.id) = 0;
  ")

  if [ -z "$empty_users" ]; then
    echo "No users to prune (all users have tasks or are the current user)"
    return 0
  fi

  echo "Found users with 0 tasks:"
  echo "$empty_users"
  echo ""
  printf "Remove these users? [y/N]: "
  read confirm
  confirm=$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')

  if [ "$confirm" != "y" ] && [ "$confirm" != "yes" ]; then
    echo "Aborted."
    return 0
  fi

  # Delete users with 0 tasks
  deleted=$(sqlite3 "$DB_PATH" "
    DELETE FROM users
    WHERE id IN (
      SELECT u.id
      FROM users u
      LEFT JOIN tasks t ON u.id = t.user_id
      WHERE u.user != '$current_user'
      GROUP BY u.id
      HAVING COUNT(t.id) = 0
    );
    SELECT changes();
  ")

  echo "Removed $deleted user(s)"
  echo ""
  echo "⚠️  Remember to commit .todos.db to share this change"
}

# List all users with task counts
list_users() {
  DB_PATH=$(get_db_path) || return 1

  echo "Users:"
  sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT
  u.user,
  COUNT(t.id) as tasks,
  u.created_at,
  u.created_by
FROM users u
LEFT JOIN tasks t ON u.id = t.user_id
GROUP BY u.id, u.user, u.created_at, u.created_by
ORDER BY tasks DESC, u.created_at;
EOF
}

# ============================================================================
# ADVANCED/HIDDEN COMMANDS - Not recommended for normal use
# These commands exist for edge cases, testing, and admin tasks.
# Normal workflow should rely on auto-creation via ensure_current_user()
# ============================================================================

# Add a user to the database (ADVANCED - prefer auto-creation)
add_user() {
  target_user="$1"

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    echo "Usage: todos user add <username>" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path) || return 1

  # Check if user already exists
  user_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -gt 0 ]; then
    echo "Error: User '$target_user' already exists" >&2
    return 1
  fi

  # Add user
  sqlite3 "$DB_PATH" "INSERT INTO users (user, created_by) VALUES ('$target_user', '$current_user');"

  echo "Added user: $target_user"
  echo ""
  echo "⚠️  Remember to commit .todos.db to share this change"
  echo ""
  echo "NOTE: This is an advanced command. Users are normally auto-created."
  echo "      See 'todos user --help' for details."
}

# Delete a user from the database (ADVANCED - prefer 'user remove')
del_user() {
  target_user="$1"

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    echo "Usage: todos user del <username>" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path) || return 1

  # Check if user exists
  user_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -eq 0 ]; then
    echo "Error: User '$target_user' not found" >&2
    return 1
  fi

  # Prevent deleting yourself
  if [ "$target_user" = "$current_user" ]; then
    echo "Error: Cannot delete your own user account" >&2
    return 1
  fi

  # Check if user has tasks (WARNING, not blocking)
  user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$target_user';")
  task_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE user_id = $user_id;")

  if [ "$task_count" -gt 0 ]; then
    echo "⚠️  WARNING: User '$target_user' owns $task_count task(s)" >&2
    echo "Deleting this user will NOT delete their tasks, but may break references." >&2
    echo "" >&2
    printf "Continue anyway? [y/N]: "
    read confirm
    confirm=$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')

    if [ "$confirm" != "y" ] && [ "$confirm" != "yes" ]; then
      echo "Aborted."
      return 0
    fi
  fi

  # Delete user
  sqlite3 "$DB_PATH" "DELETE FROM users WHERE user = '$target_user';"

  echo "Deleted user: $target_user"
  echo ""
  echo "⚠️  Remember to commit .todos.db to share this change"
  echo ""
  echo "NOTE: This is an advanced command. Prefer 'todos user remove' (safe)"
  echo "      or 'todos reassign-all' + 'todos user remove' workflow."
  echo "      See 'todos user --help' for details."
}
