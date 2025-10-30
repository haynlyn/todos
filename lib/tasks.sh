#!/bin/sh

list_todos() {
  conditions=""
  while [ "$#" -gt 0 ]; do
    case $1 in 
      -t|--topic)
        # echo "Look for todos for a specific topic"
        if [ -z "$topics" -o ${#topics} = 0 ]; then
          topics="'$2'"
        else
          topics=$topics",'$2'"
        fi
        shift
        ;;
      -u|--user)
        # echo "Look for todos for a specific user, or the calling user"
        # This could mean any todos they made, or any todos belonging to a topic
        # to which they've subscribed
        if [ -z "$users" -o ${#users} = 0 ]; then
          if [ -z "$2" ]; then user="$(whoami)"; else user="$2"; shift; fi
          users="'$user'" 
        else
          users=$users",'$2'"; shift
        fi
        ;;
      -i|--incomplete)
        # echo "Look for incomplete todos"
        conditions=$conditions" AND status != 'DONE'"
        ;;
      -d|--done)
        # echo "Look for complete todos"
        conditions=$conditions" and status = 'DONE'"
        ;;
      -l|--late)
        # echo "Look for late todos"
        conditions=$conditions" and due_date < CURRENT_TIMESTAMP"
        ;;
      --title) # delete this?
        ;;
      -f|--file)
        # echo "Look for any todos mentioned in a file"
        if [ -z "$files" -o ${#files} = 0 ]; then
          files="'$2'"
        else
          files=$files",'$2'"
        fi
        shift
        ;;
      *)
        echo "Usage specify topics and/or users via list, and specify todo status"
        ;;

    esac
    shift
  done
  if [ -z ]
  sql_command="
SELECT DISTINCT todo
FROM todos
WHERE 1=1

"
}
