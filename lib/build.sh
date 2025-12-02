#!/bin/sh

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"
. "$LIBDIR/users.sh"
# build library - scans for TODOs in code and .todo files


build_from_files() {
  # Scan for .todo files, TODO statements, or TODOS blocks
  DB_PATH=$(get_db_path) || return 1

  scan_dir="."
  from_type="auto"
  assignment_strategy=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      --from)
        from_type="$2"
        shift 2
        ;;
      -d|--directory)
        scan_dir="$2"
        shift 2
        ;;
      --assign-to-me)
        assignment_strategy="assign-to-me"
        shift
        ;;
      --unassigned)
        assignment_strategy="unassigned"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  # Default to unassigned if no strategy specified
  if [ -z "$assignment_strategy" ]; then
    assignment_strategy="unassigned"
  fi

  # Ensure current user exists (needed for --assign-to-me)
  if [ "$assignment_strategy" = "assign-to-me" ]; then
    ensure_current_user
    user_id=$(get_current_user_id)
  else
    user_id=""  # Unassigned
  fi

  echo "Scanning directory: $scan_dir"

  case $from_type in
    auto|all)
      scan_todo_files "$scan_dir" "$user_id" "$DB_PATH"
      scan_todo_comments "$scan_dir" "$user_id" "$DB_PATH"
      scan_todos_blocks "$scan_dir" "$user_id" "$DB_PATH"
      ;;
    todo-files)
      scan_todo_files "$scan_dir" "$user_id" "$DB_PATH"
      ;;
    comments)
      scan_todo_comments "$scan_dir" "$user_id" "$DB_PATH"
      ;;
    blocks)
      scan_todos_blocks "$scan_dir" "$user_id" "$DB_PATH"
      ;;
    *)
      echo "Error: unknown --from type: $from_type"
      echo "Valid types: auto, all, todo-files, comments, blocks"
      return 1
      ;;
  esac

  echo "Build completed"
}

scan_todo_files() {
  scan_dir="$1"
  user_id="$2"
  DB_PATH="$3"

  # Convert empty user_id to NULL for SQL
  if [ -z "$user_id" ]; then
    user_id="NULL"
  fi

  echo "Scanning for .todo files..."

  # Find all .todo files
  find "$scan_dir" -name "*.todo" -type f | while read -r todo_file; do
    echo "Processing: $todo_file"

    # Add file to files table
    sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO files (path) VALUES ('$todo_file');"
    file_id=$(sqlite3 "$DB_PATH" "SELECT id FROM files WHERE path = '$todo_file';")

    # Collect INSERT statements for this file
    batch_sql=""

    # Read each line as a potential task
    line_num=0
    while IFS= read -r line || [ -n "$line" ]; do
      line_num=$((line_num + 1))

      # Skip empty lines
      if [ -z "$line" ]; then
        continue
      fi

      # Parse line for task information
      # Format: "content | optional title"
      # content is required (the task itself), title is optional (summary)
      content=$(echo "$line" | cut -d'|' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      title=$(echo "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [ "$title" = "$content" ]; then
        title=""
      fi

      # Escape single quotes for SQL
      content=$(echo "$content" | sed "s/'/''/g")
      title=$(echo "$title" | sed "s/'/''/g")

      # Collect INSERT statement (title is optional)
      if [ -n "$title" ]; then
        batch_sql="$batch_sql
INSERT INTO tasks (user_id, file_id, line_start, content, title, status, created_at)
VALUES ($user_id, $file_id, $line_num, '$content', '$title', 'TODO', datetime('now'));"
      else
        batch_sql="$batch_sql
INSERT INTO tasks (user_id, file_id, line_start, content, status, created_at)
VALUES ($user_id, $file_id, $line_num, '$content', 'TODO', datetime('now'));"
      fi
    done < "$todo_file"

    # Execute batch insert for this file
    if [ -n "$batch_sql" ]; then
      sqlite3 "$DB_PATH" <<BATCHEOF
BEGIN TRANSACTION;
$batch_sql
COMMIT;
BATCHEOF
    fi
  done
}

scan_todo_comments() {
  scan_dir="$1"
  user_id="$2"
  DB_PATH="$3"

  # Convert empty user_id to NULL for SQL
  if [ -z "$user_id" ]; then
    user_id="NULL"
  fi

  echo "Scanning for TODO/TODOS comments..."

  # Find all common source files and scan for TODO comments
  # Exclude binary files, .git, node_modules, etc.
  find "$scan_dir" -type f \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/.hg/*" \
    ! -path "*/node_modules/*" \
    ! -path "*/vendor/*" \
    ! -name "*.db" \
    ! -name "*.sqlite*" \
    | while read -r source_file; do

    # Check if file is text
    if file "$source_file" | grep -q text; then

      # Add file to files table
      sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO files (path) VALUES ('$source_file');"
      file_id=$(sqlite3 "$DB_PATH" "SELECT id FROM files WHERE path = '$source_file';")

      # Collect INSERT statements for this file using a temp file to avoid subshell issues
      temp_sql="/tmp/batch_comments_$$.sql"
      > "$temp_sql"  # Clear file

      # Scan for TODO/TODOS comments with line numbers
      grep -n -E "(TODO|TODOS|FIXME|XXX|HACK|NOTE):" "$source_file" 2>/dev/null | while IFS=: read -r line_num rest; do

        # Extract the comment (remove everything up to and including the TODO: marker)
        content=$(echo "$rest" | sed -E 's/^.*(TODO|TODOS|FIXME|XXX|HACK|NOTE):[[:space:]]*//')

        # Escape single quotes for SQL
        content=$(echo "$content" | sed "s/'/''/g")

        # Append INSERT statement to temp file (no title, just content)
        echo "INSERT INTO tasks (user_id, file_id, line_start, content, status, created_at) VALUES ($user_id, $file_id, $line_num, '$content', 'TODO', datetime('now'));" >> "$temp_sql"
      done

      # Execute batch insert for this file if there were any comments
      if [ -s "$temp_sql" ]; then
        sqlite3 "$DB_PATH" <<BATCHEOF
BEGIN TRANSACTION;
$(cat "$temp_sql")
COMMIT;
BATCHEOF
      fi
      rm -f "$temp_sql"
    fi
  done
}

scan_todos_blocks() {
  # Scan for multi-line TODOS blocks:
  # 1. TODOS.START ... TODOS.END
  # 2. TODO: { ... } or TODO { ... }
  scan_dir="$1"
  user_id="$2"
  DB_PATH="$3"

  # Convert empty user_id to NULL for SQL
  if [ -z "$user_id" ]; then
    user_id="NULL"
  fi

  echo "Scanning for TODOS blocks..."

  # Find all common source files
  find "$scan_dir" -type f \
    ! -path "*/.git/*" \
    ! -path "*/.svn/*" \
    ! -path "*/.hg/*" \
    ! -path "*/node_modules/*" \
    ! -path "*/vendor/*" \
    ! -name "*.db" \
    ! -name "*.sqlite*" \
    | while read -r source_file; do

    # Check if file is text
    if file "$source_file" | grep -q text; then

      # Add file to files table
      sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO files (path) VALUES ('$source_file');"
      file_id=$(sqlite3 "$DB_PATH" "SELECT id FROM files WHERE path = '$source_file';")

      # Use temp file to collect INSERT statements for batching
      temp_sql="/tmp/batch_blocks_$$.sql"
      > "$temp_sql"  # Clear file

      # Process file to find TODOS.START/END blocks and TODO: { } blocks
      in_start_end_block=false
      in_brace_block=false
      block_content=""
      block_start_line=0
      block_end_line=0
      line_num=0
      brace_depth=0

      while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Check for TODOS.START
        if echo "$line" | grep -q "TODOS\.START"; then
          in_start_end_block=true
          block_start_line=$line_num
          block_content=""
          continue
        fi

        # Check for TODOS.END
        if echo "$line" | grep -q "TODOS\.END"; then
          if [ "$in_start_end_block" = true ]; then
            block_end_line=$line_num
            process_block "$block_content" "$user_id" "$file_id" "$block_start_line" "$block_end_line" "$temp_sql"
            in_start_end_block=false
            block_content=""
          fi
          continue
        fi

        # Check for TODO: { or TODO {
        if echo "$line" | grep -qE "(TODO|FIXME|XXX|HACK|NOTE):?[[:space:]]*\{"; then
          if [ "$in_brace_block" = false ]; then
            in_brace_block=true
            block_start_line=$line_num
            block_content=""
            brace_depth=1

            # Check if there's content after the opening brace on same line
            rest=$(echo "$line" | sed -E 's/.*\{[[:space:]]*//')
            if [ -n "$rest" -a "$rest" != "}" ]; then
              block_content="$rest"
            fi

            # Check if closing brace is on same line
            if echo "$line" | grep -q "}"; then
              brace_depth=0
              in_brace_block=false
              block_end_line=$line_num
              # Remove closing brace from content
              block_content=$(echo "$block_content" | sed 's/}[[:space:]]*$//')
              process_block "$block_content" "$user_id" "$file_id" "$block_start_line" "$block_end_line" "$temp_sql"
              block_content=""
            fi
            continue
          fi
        fi

        # If we're in a brace block, handle braces and accumulate content
        if [ "$in_brace_block" = true ]; then
          # Count opening braces
          opening=$(echo "$line" | tr -cd '{' | wc -c)
          brace_depth=$((brace_depth + opening))

          # Count closing braces
          closing=$(echo "$line" | tr -cd '}' | wc -c)
          brace_depth=$((brace_depth - closing))

          # If we've closed all braces, end the block
          if [ $brace_depth -le 0 ]; then
            # Remove closing brace from line
            line=$(echo "$line" | sed 's/}[[:space:]]*$//')
            if [ -n "$line" ]; then
              if [ -n "$block_content" ]; then
                block_content="$block_content
$line"
              else
                block_content="$line"
              fi
            fi
            block_end_line=$line_num
            process_block "$block_content" "$user_id" "$file_id" "$block_start_line" "$block_end_line" "$temp_sql"
            in_brace_block=false
            block_content=""
            brace_depth=0
          else
            # Accumulate content
            if [ -n "$block_content" ]; then
              block_content="$block_content
$line"
            else
              block_content="$line"
            fi
          fi
          continue
        fi

        # If we're in a TODOS.START/END block, accumulate content
        if [ "$in_start_end_block" = true ]; then
          if [ -n "$block_content" ]; then
            block_content="$block_content
$line"
          else
            block_content="$line"
          fi
        fi
      done < "$source_file"

      # Execute batch insert for this file if there were any blocks
      if [ -s "$temp_sql" ]; then
        sqlite3 "$DB_PATH" <<BATCHEOF
BEGIN TRANSACTION;
$(cat "$temp_sql")
COMMIT;
BATCHEOF
      fi
      rm -f "$temp_sql"

    fi
  done
}

process_block() {
  # Process a block of content and return SQL INSERT statement
  block_content="$1"
  user_id="$2"
  file_id="$3"
  block_start_line="$4"
  block_end_line="$5"
  temp_file="$6"

  # All block content becomes task content (no title)
  # Clean up comment markers from content
  content=$(echo "$block_content" | sed -E 's/^[#\/\*-]+[[:space:]]*//;s/[[:space:]]*[\*\/]*$//')
  content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Escape single quotes for SQL
  content=$(echo "$content" | sed "s/'/''/g")

  # Only append SQL if we have content
  if [ -n "$content" ]; then
    echo "INSERT INTO tasks (user_id, file_id, line_start, line_end, content, status, created_at) VALUES ($user_id, $file_id, $block_start_line, $block_end_line, '$content', 'TODO', datetime('now'));" >> "$temp_file"
  fi
}
