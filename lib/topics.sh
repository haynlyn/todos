#!/bin/sh

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"
. "$LIBDIR/users.sh"
# topics management library


subscribe_topic() {
  # Subscribe user to topic
  DB_PATH=$(get_db_path) || return 1

  topic=""
  use_specific_user=false
  specific_user=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      -t|--topic)
        topic="$2"
        shift 2
        ;;
      -u|--user)
        specific_user="$2"
        use_specific_user=true
        shift 2
        ;;
      *)
        if [ -z "$topic" ]; then
          topic="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$topic" ]; then
    echo "Error: topic is required"
    return 1
  fi

  # Ensure current user exists
  ensure_current_user

  # Get user_id (current user or specific user if -u flag was used)
  if [ "$use_specific_user" = true ]; then
    # For backward compatibility with tests using -u flag
    DB_PATH=$(get_db_path) || return 1
    user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$specific_user';")
    if [ -z "$user_id" ]; then
      echo "Error: User '$specific_user' not found" >&2
      return 1
    fi
  else
    user_id=$(get_current_user_id)
    specific_user=$(get_calling_user)
  fi

  # Create topic if not exists
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO topics (topic) VALUES ('$topic');"

  # Get topic_id
  topic_id=$(sqlite3 "$DB_PATH" "SELECT id FROM topics WHERE topic = '$topic';")

  # Add user_topic relationship
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO user_topics (user_id, topic_id, subscribed_at) VALUES ($user_id, $topic_id, datetime('now'));"

  echo "Subscribed $specific_user to topic '$topic'"
}

unsubscribe_topic() {
  # Unsubscribe user from topic
  DB_PATH=$(get_db_path) || return 1

  topic=""
  use_specific_user=false
  specific_user=""

  while [ "$#" -gt 0 ]; do
    case $1 in
      -t|--topic)
        topic="$2"
        shift 2
        ;;
      -u|--user)
        specific_user="$2"
        use_specific_user=true
        shift 2
        ;;
      *)
        if [ -z "$topic" ]; then
          topic="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$topic" ]; then
    echo "Error: topic is required"
    return 1
  fi

  # Ensure current user exists
  ensure_current_user

  # Get user_id (current user or specific user if -u flag was used)
  if [ "$use_specific_user" = true ]; then
    DB_PATH=$(get_db_path) || return 1
    user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$specific_user';")
    if [ -z "$user_id" ]; then
      echo "Error: User '$specific_user' not found" >&2
      return 1
    fi
  else
    user_id=$(get_current_user_id)
    specific_user=$(get_calling_user)
  fi

  # Get topic_id
  topic_id=$(sqlite3 "$DB_PATH" "SELECT id FROM topics WHERE topic = '$topic';")

  if [ -z "$topic_id" ]; then
    echo "Error: topic not found"
    return 1
  fi

  # Remove user_topic relationship
  sqlite3 "$DB_PATH" "DELETE FROM user_topics WHERE user_id = $user_id AND topic_id = $topic_id;"

  echo "Unsubscribed $specific_user from topic '$topic'"

  # Check if topic has any subscribers or tasks
  task_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_topics WHERE topic_id = $topic_id;")
  subscriber_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM user_topics WHERE topic_id = $topic_id;")

  if [ "$task_count" -eq 0 -a "$subscriber_count" -eq 0 ]; then
    echo "Topic '$topic' is now orphaned (no tasks or subscribers)"
    # Optionally delete orphaned topic - commented out for now
    # sqlite3 "$DB_PATH" "DELETE FROM topics WHERE id = $topic_id;"
    # echo "Deleted orphaned topic '$topic'"
  fi
}

list_topics() {
  # List all topics or topics for a specific user
  DB_PATH=$(get_db_path) || return 1

  user=$(get_calling_user)
  show_all=false

  while [ "$#" -gt 0 ]; do
    case $1 in
      -u|--user)
        user="${2:-$(get_calling_user)}"
        shift
        [ -n "$2" ] && shift
        ;;
      -a|--all)
        show_all=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [ "$show_all" = true ]; then
    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT topics.id, topics.topic, COUNT(DISTINCT tt.task_id) as task_count, COUNT(DISTINCT ut.user_id) as subscriber_count
FROM topics
LEFT JOIN task_topics tt ON topics.id = tt.topic_id
LEFT JOIN user_topics ut ON topics.id = ut.topic_id
GROUP BY topics.id
ORDER BY topics.topic;
EOF
  else
    # Show topics for the specified user (defaults to current user)
    # Get user_id from users database
    user_id=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE user = '$user';")

    if [ -z "$user_id" ]; then
      echo "No topics found for user '$user' (user not in database)"
      return 0
    fi

    sqlite3 -header -column "$DB_PATH" <<EOF
SELECT topics.topic, ut.subscribed_at
FROM topics
JOIN user_topics ut ON topics.id = ut.topic_id
WHERE ut.user_id = $user_id
ORDER BY topics.topic;
EOF
  fi
}
