create_schema() {
  DB_PATH="$(dirname pwd)/test_todos.db"
  DB=$(realpath "$DB_PATH")

  if [ ! -f "$DB" ]; then
    sqlite3 "$DB" < $(dirname "$DB_PATH")/lib/test_schema.sql
    echo "Created test db."
  else
    echo "File already exists (but it shouldn't)."
  fi
}

insert_dups() {

}
