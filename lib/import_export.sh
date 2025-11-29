#!/bin/sh

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"
. "$LIBDIR/users.sh"
# import/export library for todo.txt format


import_from_todotxt() {
  # Import tasks from todo.txt format
  # Format for incomplete: (A) 2023-01-15 Task title +project @context due:2023-02-01
  # Format for completed: x 2023-01-20 2023-01-15 Task title +project @context
  # Note: We preserve priority for completed tasks even though standard todo.txt doesn't
  DB_PATH=$(get_db_path)

  input_file="$1"

  if [ -z "$input_file" ]; then
    echo "Error: must specify input file"
    return 1
  fi

  if [ ! -f "$input_file" ]; then
    echo "Error: file not found: $input_file"
    return 1
  fi

  # Ensure current user exists and get user_id
  ensure_current_user
  user_id=$(get_current_user_id)

  # Add file to files table
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO files (path) VALUES ('$input_file');"
  file_id=$(sqlite3 "$DB_PATH" "SELECT id FROM files WHERE path = '$input_file';")

  echo "Importing tasks from $input_file..."

  # Collect all INSERT statements for batch execution
  batch_sql=""
  topics_to_process=""

  line_num=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    # Skip empty lines
    if [ -z "$line" ]; then
      continue
    fi

    original_line="$line"

    # Check if task is completed
    status="TODO"
    completed_at=""
    if echo "$line" | grep -q "^x "; then
      status="DONE"
      line=$(echo "$line" | sed 's/^x //')

      # Extract completion date (first date after 'x ')
      if echo "$line" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
        completed_at=$(echo "$line" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
        line=$(echo "$line" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} //')
      fi
    fi

    # Extract priority (A-Z) - can be present for both incomplete and completed tasks
    priority=""
    if echo "$line" | grep -qE '^\([A-Z]\) '; then
      priority_letter=$(echo "$line" | sed -E 's/^\(([A-Z])\).*/\1/')
      # Convert letter to number (A=1, B=2, etc.)
      priority=$(printf "%d" "'$priority_letter")
      priority=$((priority - 64))
      line=$(echo "$line" | sed -E 's/^\([A-Z]\) //')
    fi

    # Extract creation date
    created_at=""
    if echo "$line" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
      created_at=$(echo "$line" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
      line=$(echo "$line" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} //')
    fi

    # Extract special key:value tags that map to task fields
    # Valid keys: due, pri, status, content/note
    due_date=""
    content=""
    updated_at=""

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

    # Extract content/note (multi-word values in quotes or single word)
    if echo "$line" | grep -qE 'note:"[^"]+"'; then
      content=$(echo "$line" | grep -oE 'note:"[^"]+"' | sed 's/note:"//;s/"$//')
      line=$(echo "$line" | sed -E 's/note:"[^"]+"//g')
    elif echo "$line" | grep -qE 'note:[^[:space:]]+'; then
      content=$(echo "$line" | grep -oE 'note:[^[:space:]]+' | cut -d: -f2)
      line=$(echo "$line" | sed -E 's/note:[^[:space:]]+//g')
    fi

    # Extract status override (if specified)
    if echo "$line" | grep -qE 'status:[A-Z]+'; then
      status=$(echo "$line" | grep -oE 'status:[A-Z]+' | cut -d: -f2)
      line=$(echo "$line" | sed -E 's/status:[A-Z]+//g')
    fi

    # Extract projects (+project) and contexts (@context) - these will be topics
    # Convert to single line with spaces for easier iteration
    topics=$(echo "$line" | grep -oE '(\+[a-zA-Z0-9_-]+|@[a-zA-Z0-9_-]+)' | tr '\n' ' ')

    # Remove projects, contexts, and remaining whitespace - this becomes task content
    task_content=$(echo "$line" | sed -E 's/(\+[a-zA-Z0-9_-]+|@[a-zA-Z0-9_-]+)//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # In todo.txt format:
    # - The main line becomes 'content' (required)
    # - The 'note:' field could become 'title' (optional summary), but we'll ignore it for now
    # This keeps it simple and todo.txt compatible

    # Escape single quotes for SQL
    task_content=$(echo "$task_content" | sed "s/'/''/g")
    # content variable from note: field is discarded - todo.txt is single-line focused

    # Build SQL INSERT statement with all possible fields
    sql_fields="user_id, file_id, line_start, content, status"
    sql_values="$user_id, $file_id, $line_num, '$task_content', '$status'"

    if [ -n "$priority" ]; then
      sql_fields="$sql_fields, priority"
      sql_values="$sql_values, $priority"
    fi

    if [ -n "$created_at" ]; then
      sql_fields="$sql_fields, created_at"
      sql_values="$sql_values, '$created_at'"
    else
      sql_fields="$sql_fields, created_at"
      sql_values="$sql_values, datetime('now')"
    fi

    if [ -n "$completed_at" ]; then
      sql_fields="$sql_fields, completed_at"
      sql_values="$sql_values, '$completed_at'"
    fi

    if [ -n "$due_date" ]; then
      sql_fields="$sql_fields, due_date"
      sql_values="$sql_values, '$due_date'"
    fi

    # Collect INSERT statement for batch execution
    batch_sql="$batch_sql
INSERT INTO tasks ($sql_fields) VALUES ($sql_values);"

    # Store topics for this line number (process after batch insert)
    if [ -n "$topics" ]; then
      topics_to_process="$topics_to_process
$line_num:$topics"
    fi

  done < "$input_file"

  # Execute all INSERTs in a single transaction
  echo "Executing batch insert of $line_num tasks..."
  sqlite3 "$DB_PATH" <<BATCHEOF
BEGIN TRANSACTION;
$batch_sql
COMMIT;
BATCHEOF

  # Now process topics for all tasks
  if [ -n "$topics_to_process" ]; then
    echo "Processing topics..."

    # Use temp files to avoid subshell issues
    temp_topics="/tmp/topics_batch_$$.sql"
    temp_links="/tmp/links_batch_$$.sql"
    > "$temp_topics"
    > "$temp_links"

    # First, collect all unique topics and insert them in batch
    echo "$topics_to_process" | while IFS=: read -r task_line_num topic_list; do
      if [ -z "$task_line_num" ]; then
        continue
      fi

      for topic_str in $topic_list; do
        if [ -z "$topic_str" ]; then
          continue
        fi
        topic=$(echo "$topic_str" | sed 's/^[@+]//')
        echo "$topic"
      done
    done | sort -u | while read -r topic; do
      if [ -n "$topic" ]; then
        echo "INSERT OR IGNORE INTO topics (topic) VALUES ('$topic');" >> "$temp_topics"
      fi
    done

    # Execute topic inserts in batch
    if [ -s "$temp_topics" ]; then
      sqlite3 "$DB_PATH" <<TOPICBATCH
BEGIN TRANSACTION;
$(cat "$temp_topics")
COMMIT;
TOPICBATCH
    fi

    # Now link tasks to topics in batch using subqueries to avoid separate SELECTs
    echo "$topics_to_process" | while IFS=: read -r task_line_num topic_list; do
      if [ -z "$task_line_num" ]; then
        continue
      fi

      # Process each topic using for loop to handle space-separated topics
      for topic_str in $topic_list; do
        if [ -z "$topic_str" ]; then
          continue
        fi

        # Remove + or @ prefix to get topic name
        topic=$(echo "$topic_str" | sed 's/^[@+]//')

        # Use subqueries to look up IDs inline - avoids 1500 separate SELECT queries
        echo "INSERT OR IGNORE INTO task_topics (task_id, topic_id) VALUES ((SELECT id FROM tasks WHERE file_id = $file_id AND line_start = $task_line_num), (SELECT id FROM topics WHERE topic = '$topic'));" >> "$temp_links"
      done
    done

    # Execute task_topic links in batch
    if [ -s "$temp_links" ]; then
      sqlite3 "$DB_PATH" <<LINKBATCH
BEGIN TRANSACTION;
$(cat "$temp_links")
COMMIT;
LINKBATCH
    fi

    # Clean up temp files
    rm -f "$temp_topics" "$temp_links"
  fi

  echo "Import completed: $line_num lines processed"
}

export_to_todotxt() {
  # Export tasks to todo.txt format
  # Format for incomplete: (A) 2023-01-15 Task title +project @context due:2023-02-01
  # Format for completed: x 2023-01-20 (A) 2023-01-15 Task title +project @context
  # Note: We export priority for completed tasks (non-standard) to preserve full task data
  DB_PATH=$(get_db_path)

  output_file="${1:-todo.txt}"
  user=$(get_calling_user)

  # Options for filtering
  show_done=false
  show_incomplete=true

  shift
  while [ "$#" -gt 0 ]; do
    case $1 in
      -a|--all)
        show_done=true
        show_incomplete=true
        shift
        ;;
      -d|--done)
        show_done=true
        show_incomplete=false
        shift
        ;;
      -i|--incomplete)
        show_done=false
        show_incomplete=true
        shift
        ;;
      -u|--user)
        user="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  echo "Exporting tasks to $output_file..."

  # Build WHERE clause
  where_clause="1=1"
  if [ "$show_done" = false -a "$show_incomplete" = true ]; then
    where_clause="$where_clause AND tasks.status != 'DONE'"
  elif [ "$show_done" = true -a "$show_incomplete" = false ]; then
    where_clause="$where_clause AND tasks.status = 'DONE'"
  fi

  # Get user_id from users database
  user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$user';")

  if [ -n "$user_id" ]; then
    where_clause="$where_clause AND tasks.user_id = $user_id"
  fi

  # Query tasks and export - content is required, title is optional
  sqlite3 -separator '|' "$DB_PATH" <<EOF | while IFS='|' read -r task_id content priority status created_at completed_at due_date title; do
SELECT tasks.id, tasks.content, tasks.priority, tasks.status, tasks.created_at, tasks.completed_at, tasks.due_date, tasks.title
FROM tasks
WHERE $where_clause
ORDER BY tasks.status DESC, tasks.priority ASC, tasks.created_at ASC;
EOF

    # Format line
    line=""

    # Add completion marker and completion date for done tasks
    if [ "$status" = "DONE" ]; then
      line="x"
      if [ -n "$completed_at" -a "$completed_at" != "" ]; then
        # Extract just the date part (YYYY-MM-DD)
        comp_date=$(echo "$completed_at" | cut -d' ' -f1)
        line="$line $comp_date"
      fi
      line="$line "
    fi

    # Add priority for all tasks (both complete and incomplete)
    if [ -n "$priority" -a "$priority" != "" ]; then
      # Convert number to letter (1=A, 2=B, etc.)
      priority_num=$priority
      priority_letter=$(printf "\\$(printf '%03o' $((priority_num + 64)))")
      line="$line($priority_letter) "
    fi

    # Add creation date
    if [ -n "$created_at" -a "$created_at" != "" ]; then
      # Extract just the date part
      date_part=$(echo "$created_at" | cut -d' ' -f1)
      line="$line$date_part "
    fi

    # Add content (the actual task)
    line="$line$content"

    # Get topics for this task
    topics=$(sqlite3 "$DB_PATH" <<TOPICS
SELECT topics.topic
FROM topics
JOIN task_topics ON topics.id = task_topics.topic_id
WHERE task_topics.task_id = $task_id;
TOPICS
)

    # Add topics to line (as +topic for contexts)
    for topic in $topics; do
      line="$line +$topic"
    done

    # Add special key:value tags for all relevant fields
    if [ -n "$due_date" -a "$due_date" != "" ]; then
      # Extract just the date part
      due_date_part=$(echo "$due_date" | cut -d' ' -f1)
      line="$line due:$due_date_part"
    fi

    # Add title as note if present (optional field for Jira-style summary)
    if [ -n "$title" -a "$title" != "" ]; then
      # Quote title if it contains spaces
      if echo "$title" | grep -q ' '; then
        line="$line note:\"$title\""
      else
        line="$line note:$title"
      fi
    fi

    # Add status if it's not standard TODO/DONE
    if [ "$status" != "TODO" -a "$status" != "DONE" ]; then
      line="$line status:$status"
    fi

    # Write line to file
    echo "$line"

  done > "$output_file"

  echo "Export completed to $output_file"
}
