#!/bin/sh
# Sample shell script with TODO comments

# TODO: Add command-line argument parsing
# FIXME: Handle spaces in file paths properly

backup_files() {
  # NOTE: This only backs up files modified in last 24 hours
  # XXX: Need to add incremental backup support
  find . -type f -mtime -1 -exec cp {} /backup/ \;
}

# TODO: {
#   Add compression for backup files
#   Implement rotation policy for old backups
# }

deploy_app() {
  # TODOS.START
  # Add health check before deployment
  # Implement rollback mechanism
  # Send notification on deployment completion
  # TODOS.END

  echo "Deploying application..."
}

# HACK: Temporary solution for permission issues
chmod 777 /tmp/app_data
