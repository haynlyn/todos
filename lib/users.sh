#!/bin/sh
# User management functions

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"

# NOTE: init_users_db() has been removed - users are now initialized in lib/db.sh init_db()

# Ensure current user exists in database
ensure_current_user() {
  # Use TODOS_TEST_USER for testing, otherwise whoami
  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  # Check if users database exists
  if [ ! -f "$USERS_DB" ]; then
    echo "Error: User database not found. Run 'todos init' first." >&2
    return 1
  fi

  # Check if user exists
  user_exists=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$current_user';")

  if [ "$user_exists" -eq 0 ]; then
    # Auto-create user
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO users (user, role, created_by)
VALUES ('$current_user', 'user', '$current_user');

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('add_user', '$current_user', '$current_user', 'Auto-created on first command');
EOF
    echo "Created user: $current_user"
  fi
}

# Get current user's ID
get_current_user_id() {
  # Use TODOS_TEST_USER for testing, otherwise whoami
  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$current_user';"
}

# Check if current user is admin
is_admin() {
  # Use TODOS_TEST_USER for testing, otherwise whoami
  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  count=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$current_user' AND role = 'admin';")

  [ "$count" -gt 0 ]
}

# Require admin privileges or exit
require_admin() {
  if ! is_admin; then
    echo "Error: This command requires admin privileges" >&2
    echo "" >&2
    echo "Only admin users can perform this operation." >&2
    echo "Contact your project administrator for access." >&2
    exit 1
  fi
}

# Internal function to add a user without admin checks
# Used by tests and internal operations
add_user() {
  target_user="$1"
  role="${2:-user}"
  created_by="${3:-system}"

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    return 1
  fi

  DB_PATH=$(get_db_path)

  # Check if user already exists
  user_exists=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -gt 0 ]; then
    echo "Error: User '$target_user' already exists" >&2
    return 1
  fi

  # Add user
  sqlite3 "$DB_PATH" <<EOF
INSERT INTO users (user, role, created_by)
VALUES ('$target_user', '$role', '$created_by');

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('add_user', '$target_user', '$created_by', 'role=$role');
EOF

  return 0
}

# Internal function to delete a user without admin checks
# Used by tests and internal operations
del_user() {
  target_user="$1"

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    return 1
  fi

  DB_PATH=$(get_db_path)

  # Check if user exists
  user_exists=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -eq 0 ]; then
    echo "Error: User '$target_user' not found" >&2
    return 1
  fi

  # Delete user
  sqlite3 "$DB_PATH" "DELETE FROM users WHERE user = '$target_user';"

  return 0
}

# Add user (admin only)
admin_add_user() {
  target_user="$1"
  role="${2:-user}"

  require_admin

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    echo "Usage: todos admin user add <username> [role]" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  # Check if user already exists
  user_exists=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -gt 0 ]; then
    echo "Error: User '$target_user' already exists" >&2
    return 1
  fi

  # Add user
  sqlite3 "$DB_PATH" <<EOF
INSERT INTO users (user, role, created_by)
VALUES ('$target_user', '$role', '$current_user');

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('add_user', '$target_user', '$current_user', 'role=$role');
EOF

  echo "Added user: $target_user (role: $role)"
  echo ""
  echo "⚠️  Remember to commit .todos.users.db to share this change"
}

# Delete user (admin only)
admin_del_user() {
  target_user="$1"

  require_admin

  if [ -z "$target_user" ]; then
    echo "Error: Username required" >&2
    echo "Usage: todos admin user del <username>" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  # Check if user exists
  user_exists=$(sqlite3 "$USERS_DB" "SELECT COUNT(*) FROM users WHERE user = '$target_user';")
  if [ "$user_exists" -eq 0 ]; then
    echo "Error: User '$target_user' not found" >&2
    return 1
  fi

  # Prevent deleting yourself
  if [ "$target_user" = "$current_user" ]; then
    echo "Error: Cannot delete your own user account" >&2
    return 1
  fi

  # Delete user
  sqlite3 "$DB_PATH" <<EOF
DELETE FROM users WHERE user = '$target_user';

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('del_user', '$target_user', '$current_user', '');
EOF

  echo "Deleted user: $target_user"
  echo ""
  echo "⚠️  Remember to commit .todos.users.db to share this change"
  echo "⚠️  Note: This does not delete tasks owned by this user"
}

# List all users
admin_list_users() {
  DB_PATH=$(get_db_path)

  echo "Users:"
  sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT user, role, created_at FROM users ORDER BY created_at;
EOF
}

# Change user role (admin only)
admin_change_role() {
  target_user="$1"
  new_role="$2"

  require_admin

  if [ -z "$target_user" ] || [ -z "$new_role" ]; then
    echo "Error: Username and role required" >&2
    echo "Usage: todos admin user role <username> <admin|user>" >&2
    return 1
  fi

  if [ "$new_role" != "admin" ] && [ "$new_role" != "user" ]; then
    echo "Error: Role must be 'admin' or 'user'" >&2
    return 1
  fi

  current_user="$(get_calling_user)"
  DB_PATH=$(get_db_path)

  # Get old role
  old_role=$(sqlite3 "$USERS_DB" "SELECT role FROM users WHERE user = '$target_user';")

  if [ -z "$old_role" ]; then
    echo "Error: User '$target_user' not found" >&2
    return 1
  fi

  if [ "$old_role" = "$new_role" ]; then
    echo "User '$target_user' already has role: $new_role"
    return 0
  fi

  # Update role
  sqlite3 "$DB_PATH" <<EOF
UPDATE users SET role = '$new_role' WHERE user = '$target_user';

INSERT INTO user_audit (action, target_user, actor, details)
VALUES ('change_role', '$target_user', '$current_user', 'old_role=$old_role, new_role=$new_role');
EOF

  echo "Changed role for '$target_user': $old_role → $new_role"
  echo ""
  echo "⚠️  Remember to commit .todos.users.db to share this change"
}
