#!/bin/sh
# Standalone uninstallation script for todos task management tool
# This script can be run independently of the todos installation

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source the shared uninstall implementation
if [ -f "$SCRIPT_DIR/lib/uninstall_impl.sh" ]; then
  . "$SCRIPT_DIR/lib/uninstall_impl.sh"
else
  echo "Error: Cannot find uninstall_impl.sh" >&2
  exit 1
fi

# Parse arguments
dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# Perform uninstall
perform_uninstall "$dry_run"
