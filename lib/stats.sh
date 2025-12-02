#!/bin/sh
# Statistics and reporting functions

# Note: LIBDIR is set by the main todos script
. "$LIBDIR/common.sh"

# Get count of tasks by status
get_status_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "Status Counts:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  status,
  COUNT(*) as count
FROM tasks
GROUP BY status
ORDER BY status;
EOF
}

# Get count of tasks by priority
get_priority_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "Priority Counts:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  CASE
    WHEN priority IS NULL THEN 'None'
    ELSE CAST(priority AS TEXT)
  END as priority_level,
  COUNT(*) as count
FROM tasks
GROUP BY priority
ORDER BY priority;
EOF
}

# Get count of tasks by date ranges (created, due, completed)
get_date_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "Date Counts:"
  echo ""
  echo "Created:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  DATE(created_at) as date,
  COUNT(*) as count
FROM tasks
WHERE created_at IS NOT NULL
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 10;
EOF

  echo ""
  echo "Due Dates:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  due_date,
  COUNT(*) as count
FROM tasks
WHERE due_date IS NOT NULL
GROUP BY due_date
ORDER BY due_date;
EOF

  echo ""
  echo "Completed:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  DATE(completed_at) as date,
  COUNT(*) as count
FROM tasks
WHERE completed_at IS NOT NULL
GROUP BY DATE(completed_at)
ORDER BY date DESC
LIMIT 10;
EOF

  echo ""
  echo "Overdue Tasks:"
  sqlite3 "$DB_PATH" <<EOF
SELECT COUNT(*) as count
FROM tasks
WHERE due_date IS NOT NULL
  AND due_date < DATE('now')
  AND status != 'DONE';
EOF
}

# Get count of tasks by topic
get_topic_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "Topic Counts:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  topics.topic,
  COUNT(task_topics.task_id) as count
FROM topics
LEFT JOIN task_topics ON topics.id = task_topics.topic_id
GROUP BY topics.topic
ORDER BY count DESC;
EOF
}

# Get count of tasks by user
get_user_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "User Task Counts:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  users.user,
  COUNT(tasks.id) as count
FROM users
LEFT JOIN tasks ON users.id = tasks.user_id
GROUP BY users.user
ORDER BY count DESC;
EOF
}

# Get count of topic subscriptions by user
get_user_subscription_counts() {
  DB_PATH=$(get_db_path) || return 1

  echo "User Topic Subscriptions:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  users.user,
  COUNT(user_topics.topic_id) as subscription_count
FROM users
LEFT JOIN user_topics ON users.id = user_topics.user_id
GROUP BY users.user
ORDER BY subscription_count DESC;
EOF
}

# Get count of tasks per topic (tasks-per-topic)
get_tasks_per_topic() {
  DB_PATH=$(get_db_path) || return 1

  echo "Tasks Per Topic:"
  sqlite3 "$DB_PATH" <<EOF
SELECT
  topics.topic,
  COUNT(task_topics.task_id) as task_count
FROM topics
LEFT JOIN task_topics ON topics.id = task_topics.topic_id
GROUP BY topics.topic
ORDER BY task_count DESC, topics.topic ASC;
EOF
}

# Show all statistics
show_stats() {
  DB_PATH=$(get_db_path) || return 1

  # Parse options
  show_all=true
  show_status=false
  show_priority=false
  show_dates=false
  show_topics=false
  show_users=false
  show_subscriptions=false
  show_tasks_per_topic=false

  while [ "$#" -gt 0 ]; do
    case $1 in
      --status)
        show_all=false
        show_status=true
        shift
        ;;
      --priority)
        show_all=false
        show_priority=true
        shift
        ;;
      --dates)
        show_all=false
        show_dates=true
        shift
        ;;
      --topics)
        show_all=false
        show_topics=true
        shift
        ;;
      --users)
        show_all=false
        show_users=true
        shift
        ;;
      --subscriptions)
        show_all=false
        show_subscriptions=true
        shift
        ;;
      --tasks-per-topic)
        show_all=false
        show_tasks_per_topic=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        return 1
        ;;
    esac
  done

  # Total count
  total=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks;")
  echo "Total Tasks: $total"
  echo ""

  # Show requested statistics
  if [ "$show_all" = true -o "$show_status" = true ]; then
    get_status_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_priority" = true ]; then
    get_priority_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_dates" = true ]; then
    get_date_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_topics" = true ]; then
    get_topic_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_users" = true ]; then
    get_user_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_subscriptions" = true ]; then
    get_user_subscription_counts
    echo ""
  fi

  if [ "$show_all" = true -o "$show_tasks_per_topic" = true ]; then
    get_tasks_per_topic
    echo ""
  fi
}
