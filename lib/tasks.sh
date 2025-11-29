#!/bin/sh

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"
. "$LIBDIR/users.sh"
# tasks management library


create_task() {
  # Parse arguments: content (required, positional), title (optional), priority, due_date, status, file
  DB_PATH=$(get_db_path)

  content=""
  title=""
  priority=""
  due_date=""
  status="TODO"
  file=""

  # Ensure current user exists in database
  ensure_current_user

  while [ "$#" -gt 0 ]; do
    case $1 in
      -t|--title)
        title="$2"
        shift 2
        ;;
      -c|--content)
        content="$2"
        shift 2
        ;;
      -p|--priority)
        priority="$2"
        shift 2
        ;;
      -d|--due-date)
        due_date="$2"
        shift 2
        ;;
      -s|--status)
        status="$2"
        shift 2
        ;;
      -f|--file)
        file="$2"
        shift 2
        ;;
      -u|--user)
        user="$2"
        shift 2
        ;;
      *)
        # First positional arg is content
        if [ -z "$content" ]; then
          content="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$content" ]; then
    echo "Error: content is required"
    echo "Usage: todos create <content> [-t title] [-p priority] [-d due-date] [-s status] [-f file]"
    return 1
  fi

  # Escape single quotes for SQL
  content=$(echo "$content" | sed "s/'/''/g")
  title=$(echo "$title" | sed "s/'/''/g")

  # Get user_id from users database (user already ensured to exist)
  user_id=$(get_current_user_id)

  # Get or create file_id if file specified
  file_id=""
  if [ -n "$file" ]; then
    sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO files (path) VALUES ('$file');"
    file_id=$(sqlite3 "$DB_PATH" "SELECT id FROM files WHERE path = '$file';")
  fi

  # Insert task
  if [ -n "$due_date" ]; then
    due_date_value="'$due_date'"
  else
    due_date_value="NULL"
  fi

  # Build INSERT with optional title
  if [ -n "$title" ]; then
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tasks (user_id, file_id, content, title, priority, status, due_date, created_at)
VALUES ($user_id, ${file_id:-NULL}, '$content', '$title', ${priority:-NULL}, '$status', $due_date_value, datetime('now'));
EOF
  else
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO tasks (user_id, file_id, content, priority, status, due_date, created_at)
VALUES ($user_id, ${file_id:-NULL}, '$content', ${priority:-NULL}, '$status', $due_date_value, datetime('now'));
EOF
  fi

  # Display what was created (title if present, otherwise first part of content)
  if [ -n "$title" ]; then
    echo "Created task: $title"
  else
    # Show first 50 chars of content
    display_content=$(echo "$content" | cut -c1-50)
    if [ ${#content} -gt 50 ]; then
      display_content="$display_content..."
    fi
    echo "Created task: $display_content"
  fi
}

delete_task() {
  # Delete by id or title
  DB_PATH=$(get_db_path)

  identifier=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      -i|--id)
        identifier="id = $2"
        shift 2
        ;;
      -t|--title)
        # Escape single quotes for SQL
        escaped=$(echo "$2" | sed "s/'/''/g")
        identifier="title = '$escaped'"
        shift 2
        ;;
      *)
        # Default to treating positional argument as ID
        if echo "$1" | grep -qE '^[0-9]+$'; then
          identifier="id = $1"
        else
          echo "Error: task identifier must be a numeric ID. Use -t flag to delete by title."
          return 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$identifier" ]; then
    echo "Error: must specify task id or title"
    return 1
  fi

  # Delete from task_topics first (foreign key constraint)
  sqlite3 "$DB_PATH" "DELETE FROM task_topics WHERE task_id IN (SELECT id FROM tasks WHERE $identifier);"

  # Delete from project_tasks
  sqlite3 "$DB_PATH" "DELETE FROM project_tasks WHERE task_id IN (SELECT id FROM tasks WHERE $identifier);"

  # Delete the task
  sqlite3 "$DB_PATH" "DELETE FROM tasks WHERE $identifier;"

  echo "Deleted task where $identifier"
}

list_tasks() {
  DB_PATH=$(get_db_path)

  conditions="1=1"
  joins=""
  sort_by="created_at DESC"

  while [ "$#" -gt 0 ]; do
    case $1 in
      -t|--topic)
        joins="$joins LEFT JOIN task_topics tt ON tasks.id = tt.task_id LEFT JOIN topics ON tt.topic_id = topics.id"
        conditions="$conditions AND topics.topic = '$2'"
        shift 2
        ;;
      -u|--user)
        user_name="${2:-$(get_calling_user)}"
        # Get user_id from users database
        filter_user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$user_name';")
        if [ -z "$filter_user_id" ]; then
          echo "Error: User '$user_name' not found in database" >&2
          return 1
        fi
        conditions="$conditions AND tasks.user_id = $filter_user_id"
        shift
        [ -n "$2" ] && shift
        ;;
      -i|--incomplete)
        conditions="$conditions AND status != 'DONE'"
        shift
        ;;
      -d|--done)
        conditions="$conditions AND status = 'DONE'"
        shift
        ;;
      -l|--late)
        conditions="$conditions AND due_date < datetime('now')"
        shift
        ;;
      -f|--file)
        joins="$joins LEFT JOIN files ON tasks.file_id = files.id"
        conditions="$conditions AND files.path = '$2'"
        shift 2
        ;;
      -p|--priority)
        conditions="$conditions AND priority = $2"
        shift 2
        ;;
      --id)
        conditions="$conditions AND tasks.id = $2"
        shift 2
        ;;
      --sort-by)
        sort_by="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        shift
        ;;
    esac
  done

  sqlite3 -header -column "$DB_PATH" <<EOF
SELECT DISTINCT
  tasks.id,
  COALESCE(tasks.title, substr(tasks.content, 1, 50)) as title,
  tasks.status,
  tasks.priority,
  tasks.due_date,
  tasks.created_at
FROM tasks
$joins
WHERE $conditions
ORDER BY $sort_by;
EOF
}

update_task() {
  # Update task content, status, due_date, priority
  DB_PATH=$(get_db_path)

  identifier=""
  updates=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      -i|--id)
        identifier="id = $2"
        shift 2
        ;;
      --title-match)
        escaped_title=$(echo "$2" | sed "s/'/''/g")
        identifier="title = '$escaped_title'"
        shift 2
        ;;
      -c|--content)
        escaped_content=$(echo "$2" | sed "s/'/''/g")
        updates="$updates content = '$escaped_content',"
        shift 2
        ;;
      -s|--status)
        escaped_status=$(echo "$2" | sed "s/'/''/g")
        updates="$updates status = '$escaped_status',"
        shift 2
        ;;
      -d|--due-date)
        escaped_date=$(echo "$2" | sed "s/'/''/g")
        updates="$updates due_date = '$escaped_date',"
        shift 2
        ;;
      -p|--priority)
        updates="$updates priority = $2,"
        shift 2
        ;;
      -t|--title)
        escaped_title=$(echo "$2" | sed "s/'/''/g")
        updates="$updates title = '$escaped_title',"
        shift 2
        ;;
      *)
        if [ -z "$identifier" ]; then
          if echo "$1" | grep -qE '^[0-9]+$'; then
            identifier="id = $1"
          fi
        fi
        shift
        ;;
    esac
  done

  if [ -z "$identifier" ]; then
    echo "Error: must specify task id or title"
    return 1
  fi

  if [ -z "$updates" ]; then
    echo "Error: no updates specified"
    return 1
  fi

  # Remove trailing comma
  updates=$(echo "$updates" | sed 's/,$//')

  sqlite3 "$DB_PATH" <<EOF
UPDATE tasks
SET $updates, updated_at = datetime('now')
WHERE $identifier;
EOF

  echo "Updated task where $identifier"
}

tag_task() {
  # Add topic to task
  DB_PATH=$(get_db_path)

  task_id=""
  topic=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      -i|--id)
        task_id="$2"
        shift 2
        ;;
      -t|--topic)
        topic="$2"
        shift 2
        ;;
      *)
        if [ -z "$task_id" ]; then
          task_id="$1"
        elif [ -z "$topic" ]; then
          topic="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$task_id" -o -z "$topic" ]; then
    echo "Error: must specify task id and topic"
    return 1
  fi

  # Create topic if not exists
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO topics (topic) VALUES ('$topic');"

  # Get topic_id
  topic_id=$(sqlite3 "$DB_PATH" "SELECT id FROM topics WHERE topic = '$topic';")

  # Add task_topic relationship
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO task_topics (task_id, topic_id) VALUES ($task_id, $topic_id);"

  echo "Tagged task $task_id with topic '$topic'"
}

set_priority() {
  DB_PATH=$(get_db_path)

  task_id="$1"
  priority="$2"

  if [ -z "$task_id" -o -z "$priority" ]; then
    echo "Error: must specify task id and priority"
    return 1
  fi

  sqlite3 "$DB_PATH" "UPDATE tasks SET priority = $priority, updated_at = datetime('now') WHERE id = $task_id;"

  echo "Set priority of task $task_id to $priority"
}

set_deadline() {
  DB_PATH=$(get_db_path)

  task_id="$1"
  due_date="$2"

  if [ -z "$task_id" -o -z "$due_date" ]; then
    echo "Error: must specify task id and due date"
    return 1
  fi

  sqlite3 "$DB_PATH" "UPDATE tasks SET due_date = '$due_date', updated_at = datetime('now') WHERE id = $task_id;"

  echo "Set deadline of task $task_id to $due_date"
}

rename_task() {
  DB_PATH=$(get_db_path)

  task_id="$1"
  new_content="$2"

  if [ -z "$task_id" -o -z "$new_content" ]; then
    echo "Error: must specify task id and new content"
    return 1
  fi

  # Escape single quotes for SQL
  escaped_content=$(echo "$new_content" | sed "s/'/''/g")

  sqlite3 "$DB_PATH" "UPDATE tasks SET content = '$escaped_content', updated_at = datetime('now') WHERE id = $task_id;"

  echo "Renamed task $task_id to '$new_content'"
}

set_status() {
  DB_PATH=$(get_db_path)

  task_id="$1"
  status="$2"

  if [ -z "$task_id" -o -z "$status" ]; then
    echo "Error: must specify task id and status"
    return 1
  fi

  sqlite3 "$DB_PATH" "UPDATE tasks SET status = '$status', updated_at = datetime('now') WHERE id = $task_id;"

  echo "Set status of task $task_id to $status"
}
