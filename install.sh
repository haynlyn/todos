#!/bin/sh


check_requirements() {
  if [[ -z $(which sqlite3) ]]
    then echo "Please install SQLite 3." && return 1
    else echo "TODO: delete this line."
  fi

  return 0
}


main() {
  if [ check_requirements -eq 0 ]; then
    echo "NO SQLITE IN USE"
  else echo "AYYY"
  fi
}

# check_requirements
main
