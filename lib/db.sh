#!/bin/sh
# database management library
## should it also include database querying, or shoud that be separate?

init_db() {
  # TODO: update to specify whether it's a global or local db (say, for project-specific TODOs statements)
  SELF=$(realpath "$0")
  BASEDIR=$(dirname "$SELF")

  DB_PATH="$1"

  if [ -z "$DB_PATH" ]; then
    DB_PATH=$(realpath $BASEDIR/../todos.db)
  fi

  echo "Database location: $DB_PATH"

  DB=$(realpath "$DB_PATH")
  mkdir -p "$(dirname "$DB")"

  if [ ! -f "$DB" ]; then
    sqlite3 "$DB" < $(dirname "$DB_PATH")/share/schema.sql
    echo "Created new database at $DB"
  else
    echo "Using existing database at $DB"
  fi

  # TODO: Allow for user creation

  # Update todos config to use user-defined ~/.config/todos?
  # TODO: Make it so that this only occurs if there's not yet a database?
  cat > .todosrc <<EOF
DB=$DB_PATH
EOF
  echo "Wrote project config .todosrc"
}

add_user() {
  if [ -z "$1" ]; then
    echo "Error: please provide user"
    return -1
  else
    USER=$1
  fi

  SELF=$(realpath "$0")
  BASEDIR=$(dirname "$SELF")
  DB_PATH=$(realpath $BASEDIR/../todos.db)

  if [ ! -e "$DB_PATH" ]; then 
    echo "Cannot add user as there is no database"
    return -1
  fi

  sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO users (user) VALUES ('$USER');
EOF
}

del_user() {
  if [ -z "$1" ]; then
    echo "Error: please provide user"
    return -1
  else
    USER=$1
  fi

  SELF=$(realpath "$0")
  BASEDIR=$(dirname "$SELF")
  DB_PATH=$(realpath $BASEDIR/../todos.db)

  if [ ! -e "$DB_PATH" ]; then 
    echo "Cannot del user as there is no database"
    return -1
  fi

  echo "This doesn't check or handle orphaned tasks/projects/topics/etc."

  sqlite3 "$DB_PATH" <<EOF
DELETE FROM user_topics
WHERE user_id = (SELECT id FROM users WHERE user = '$USER');

DELETE FROM project_users
WHERE user_id = (SELECT id FROM users WHERE user = '$USER');

DELETE FROM users
WHERE user = '$USER';
EOF
}

import_from_db() {
}

flush_db() {
  SELF=$(realpath "$0")
  BASEDIR=$(dirname "$SELF")/..
  DB_PATH=$(realpath $BASEDIR/todos.db)
  echo $DB_PATH
  
  if [ -e $DB_PATH ]; then
    echo "Deleting database."
    rm $DB_PATH
    if [ $1 = 'true' ]; then
      echo "Rebuilding database with current user added."
      init_db
      add_user $(whoami)
    fi
    
  else
    echo "No database found - this should be moved further up. Don't allow any db operations if one doesn't exist."
  fi

  return 1
}
