#!/bin/sh
# Show readable diff of database changes since last commit

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DB_FILE="${1:-.todos.db}"
OLD_DB="/tmp/todos-old-$$.db"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
  echo "${RED}Error: Database not found: $DB_FILE${NC}" >&2
  exit 1
fi

# Get old version from git
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "${YELLOW}Not a git repository or no commits yet${NC}" >&2
  exit 0
fi

if ! git show "HEAD:$DB_FILE" > "$OLD_DB" 2>/dev/null; then
  echo "${YELLOW}Database not in previous commit (new file)${NC}"
  echo ""
  echo "${BOLD}Current database contents:${NC}"
  sqlite3 "$DB_FILE" "SELECT COUNT(*) || ' tasks' FROM tasks;"
  sqlite3 "$DB_FILE" "SELECT COUNT(*) || ' users' FROM users;"
  rm -f "$OLD_DB"
  exit 0
fi

# Helper functions
priority_to_letter() {
  case "$1" in
    1) echo "A" ;;
    2) echo "B" ;;
    3) echo "C" ;;
    4) echo "D" ;;
    5) echo "E" ;;
    *) echo "$1" ;;
  esac
}

format_task() {
  id="$1"
  title="$2"
  status="$3"
  priority="$4"
  due_date="$5"
  assigned_to="$6"

  pri_letter=$(priority_to_letter "$priority")

  output="  [${id}] ${title}"
  details=""

  [ -n "$status" ] && details="${details}status: ${status}"
  [ -n "$priority" ] && details="${details} | priority: ${pri_letter} (${priority})"
  [ -n "$due_date" ] && [ "$due_date" != "" ] && details="${details} | due: ${due_date}"
  [ -n "$assigned_to" ] && [ "$assigned_to" != "" ] && details="${details} | assigned: ${assigned_to}"

  echo "$output"
  [ -n "$details" ] && echo "      ${details}"
}

# Compare tasks
echo "${BOLD}${BLUE}Database Changes${NC}"
echo "================"
echo ""

# Tasks added
added=$(sqlite3 "$DB_FILE" "
  SELECT id, title, status, priority, due_date, assigned_to
  FROM tasks
  WHERE id NOT IN (SELECT id FROM tasks WHERE 1=1)
" 2>/dev/null | sqlite3 "$OLD_DB" "
  CREATE TEMP TABLE new_tasks(id, title, status, priority, due_date, assigned_to);
  .import /dev/stdin new_tasks
  SELECT id, title, status, priority, due_date, assigned_to
  FROM new_tasks
  WHERE id NOT IN (SELECT id FROM tasks);
" 2>/dev/null || true)

# Better approach: get all IDs from both and compare
old_ids=$(sqlite3 "$OLD_DB" "SELECT id FROM tasks ORDER BY id;" 2>/dev/null || echo "")
new_ids=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks ORDER BY id;" 2>/dev/null || echo "")

# Tasks added (in new but not in old)
has_changes=0
added_tasks=""
for id in $new_ids; do
  if ! echo "$old_ids" | grep -q "^${id}$"; then
    if [ -z "$added_tasks" ]; then
      added_tasks="${GREEN}Tasks Added:${NC}\n"
      has_changes=1
    fi
    task_info=$(sqlite3 "$DB_FILE" "SELECT id, title, status, priority, due_date, assigned_to FROM tasks WHERE id=$id;" | tr '|' '\n')
    task_id=$(echo "$task_info" | sed -n 1p)
    task_title=$(echo "$task_info" | sed -n 2p)
    task_status=$(echo "$task_info" | sed -n 3p)
    task_priority=$(echo "$task_info" | sed -n 4p)
    task_due=$(echo "$task_info" | sed -n 5p)
    task_assigned=$(echo "$task_info" | sed -n 6p)
    added_tasks="${added_tasks}$(format_task "$task_id" "$task_title" "$task_status" "$task_priority" "$task_due" "$task_assigned")\n"
  fi
done

# Tasks removed (in old but not in new)
removed_tasks=""
for id in $old_ids; do
  if ! echo "$new_ids" | grep -q "^${id}$"; then
    if [ -z "$removed_tasks" ]; then
      removed_tasks="${RED}Tasks Removed:${NC}\n"
      has_changes=1
    fi
    task_info=$(sqlite3 "$OLD_DB" "SELECT id, title, status, priority, due_date, assigned_to FROM tasks WHERE id=$id;" | tr '|' '\n')
    task_id=$(echo "$task_info" | sed -n 1p)
    task_title=$(echo "$task_info" | sed -n 2p)
    task_status=$(echo "$task_info" | sed -n 3p)
    task_priority=$(echo "$task_info" | sed -n 4p)
    task_due=$(echo "$task_info" | sed -n 5p)
    task_assigned=$(echo "$task_info" | sed -n 6p)
    removed_tasks="${removed_tasks}$(format_task "$task_id" "$task_title" "$task_status" "$task_priority" "$task_due" "$task_assigned")\n"
  fi
done

# Tasks modified (in both but different)
modified_tasks=""
for id in $new_ids; do
  if echo "$old_ids" | grep -q "^${id}$"; then
    old_task=$(sqlite3 "$OLD_DB" "SELECT title, status, priority, due_date, assigned_to FROM tasks WHERE id=$id;" 2>/dev/null)
    new_task=$(sqlite3 "$DB_FILE" "SELECT title, status, priority, due_date, assigned_to FROM tasks WHERE id=$id;" 2>/dev/null)

    if [ "$old_task" != "$new_task" ]; then
      if [ -z "$modified_tasks" ]; then
        modified_tasks="${YELLOW}Tasks Modified:${NC}\n"
        has_changes=1
      fi

      old_title=$(echo "$old_task" | cut -d'|' -f1)
      new_title=$(echo "$new_task" | cut -d'|' -f1)
      old_status=$(echo "$old_task" | cut -d'|' -f2)
      new_status=$(echo "$new_task" | cut -d'|' -f2)
      old_priority=$(echo "$old_task" | cut -d'|' -f3)
      new_priority=$(echo "$new_task" | cut -d'|' -f3)
      old_due=$(echo "$old_task" | cut -d'|' -f4)
      new_due=$(echo "$new_task" | cut -d'|' -f4)
      old_assigned=$(echo "$old_task" | cut -d'|' -f5)
      new_assigned=$(echo "$new_task" | cut -d'|' -f5)

      modified_tasks="${modified_tasks}  [${id}] ${new_title}\n"

      [ "$old_title" != "$new_title" ] && modified_tasks="${modified_tasks}      title: ${old_title} → ${new_title}\n"
      [ "$old_status" != "$new_status" ] && modified_tasks="${modified_tasks}      status: ${old_status} → ${new_status}\n"
      if [ "$old_priority" != "$new_priority" ]; then
        old_pri=$(priority_to_letter "$old_priority")
        new_pri=$(priority_to_letter "$new_priority")
        modified_tasks="${modified_tasks}      priority: ${old_pri} (${old_priority}) → ${new_pri} (${new_priority})\n"
      fi
      [ "$old_due" != "$new_due" ] && modified_tasks="${modified_tasks}      due: ${old_due} → ${new_due}\n"
      [ "$old_assigned" != "$new_assigned" ] && modified_tasks="${modified_tasks}      assigned: ${old_assigned} → ${new_assigned}\n"
    fi
  fi
done

# Users changed
old_users=$(sqlite3 "$OLD_DB" "SELECT user FROM users ORDER BY user;" 2>/dev/null || echo "")
new_users=$(sqlite3 "$DB_FILE" "SELECT user FROM users ORDER BY user;" 2>/dev/null || echo "")

users_added=""
users_removed=""

for user in $new_users; do
  if ! echo "$old_users" | grep -q "^${user}$"; then
    if [ -z "$users_added" ]; then
      users_added="${CYAN}Users Added:${NC}\n"
      has_changes=1
    fi
    task_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE assigned_to='$user';" 2>/dev/null || echo "0")
    users_added="${users_added}  ${user} (${task_count} tasks)\n"
  fi
done

for user in $old_users; do
  if ! echo "$new_users" | grep -q "^${user}$"; then
    if [ -z "$users_removed" ]; then
      users_removed="${CYAN}Users Removed:${NC}\n"
      has_changes=1
    fi
    users_removed="${users_removed}  ${user}\n"
  fi
done

# Output results
if [ $has_changes -eq 0 ]; then
  echo "${GREEN}No changes${NC}"
else
  [ -n "$added_tasks" ] && printf "$added_tasks\n"
  [ -n "$modified_tasks" ] && printf "$modified_tasks\n"
  [ -n "$removed_tasks" ] && printf "$removed_tasks\n"
  [ -n "$users_added" ] && printf "$users_added\n"
  [ -n "$users_removed" ] && printf "$users_removed\n"
fi

# Cleanup
rm -f "$OLD_DB"
