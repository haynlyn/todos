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

parse_todotxt_line() {
  # Parse a todo.txt format line and extract components
  # Format: [(A)] [2024-01-15] Task content +project @context due:2024-02-01
  # Returns colon-separated values: priority:due_date:content:topics
  # Example: 1:2024-02-01:Task content:+project @context

  line="$1"

  # Initialize output variables
  priority=""
  due_date=""
  created_at=""
  topics=""

  # Extract priority (A-Z)
  if echo "$line" | grep -qE '^\([A-Z]\) '; then
    priority_letter=$(echo "$line" | sed -E 's/^\(([A-Z])\).*/\1/')
    # Convert letter to number (A=1, B=2, etc.)
    priority=$(printf "%d" "'$priority_letter")
    priority=$((priority - 64))
    line=$(echo "$line" | sed -E 's/^\([A-Z]\) //')
  fi

  # Extract creation date (if present after priority)
  if echo "$line" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
    created_at=$(echo "$line" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
    line=$(echo "$line" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} //')
  fi

  # Extract due date (due:YYYY-MM-DD)
  if echo "$line" | grep -qE 'due:[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    due_date=$(echo "$line" | grep -oE 'due:[0-9]{4}-[0-9]{2}-[0-9]{2}' | cut -d: -f2)
    line=$(echo "$line" | sed -E 's/due:[0-9]{4}-[0-9]{2}-[0-9]{2}//g')
  fi

  # Allow pri:A format as alternative to (A) prefix
  if [ -z "$priority" ] && echo "$line" | grep -qE 'pri:[A-Z]'; then
    priority_letter=$(echo "$line" | grep -oE 'pri:[A-Z]' | cut -d: -f2)
    priority=$(printf "%d" "'$priority_letter")
    priority=$((priority - 64))
    line=$(echo "$line" | sed -E 's/pri:[A-Z]//g')
  fi

  # Extract projects (+project) and contexts (@context) - these will be topics
  topics=$(echo "$line" | grep -oE '(\+[a-zA-Z0-9_-]+|@[a-zA-Z0-9_-]+)' | tr '\n' ' ')

  # Remove projects, contexts, and collapse multiple spaces - this becomes task content
  content=$(echo "$line" | sed -E 's/(\+[a-zA-Z0-9_-]+|@[a-zA-Z0-9_-]+)//g' | sed -E 's/[[:space:]]+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Output format: priority|due_date|content|topics|created_at
  echo "$priority|$due_date|$content|$topics|$created_at"
}
