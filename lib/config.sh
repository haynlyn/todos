#!/bin/sh
# Configuration management library for user settings
# Supports global (${XDG_CONFIG_HOME:-~/.config}/todos/config) and project-local (.todos/config) settings

# Get global config file path (uses XDG_CONFIG_HOME)
get_global_config_path() {
  echo "${XDG_CONFIG_HOME:-$HOME/.config}/todos/config"
}

# Get project-local config file path
get_project_config_path() {
  # Find project root (where .todos.db is or will be)
  current_dir="$PWD"

  while [ "$current_dir" != "/" ]; do
    if [ -f "$current_dir/.todos.db" ] || [ -f "$current_dir/.todos/config" ]; then
      echo "$current_dir/.todos/config"
      return 0
    fi
    current_dir=$(dirname "$current_dir")
  done

  # No project root found, use current directory
  echo "$PWD/.todos/config"
}

# Get config value (project-local overrides global)
get_config() {
  key="$1"

  if [ -z "$key" ]; then
    echo "Error: must specify config key" >&2
    return 1
  fi

  # Check project-local config first (higher priority)
  project_config=$(get_project_config_path)
  if [ -f "$project_config" ]; then
    value=$(grep -F "$key=" "$project_config" 2>/dev/null | grep "^$key=" | cut -d= -f2-)
    if [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
  fi

  # Fall back to global config
  global_config=$(get_global_config_path)
  if [ -f "$global_config" ]; then
    value=$(grep -F "$key=" "$global_config" 2>/dev/null | grep "^$key=" | cut -d= -f2-)
    if [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
  fi

  # Key not found in either config
  return 1
}

# Get config value with default
get_config_or_default() {
  key="$1"
  default="$2"

  value=$(get_config "$key" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

# Set config value
# Usage: set_config [--global|--project] <key> <value>
set_config() {
  scope="--project"  # Default to project-local

  # Parse scope flag
  case "$1" in
    --global)
      scope="--global"
      shift
      ;;
    --project)
      scope="--project"
      shift
      ;;
  esac

  key="$1"
  value="$2"

  if [ -z "$key" ]; then
    echo "Error: must specify config key" >&2
    echo "Usage: todos config set [--global|--project] <key> <value>" >&2
    return 1
  fi

  if [ -z "$value" ]; then
    echo "Error: must specify config value" >&2
    echo "Usage: todos config set [--global|--project] <key> <value>" >&2
    return 1
  fi

  # Determine target config file
  if [ "$scope" = "--global" ]; then
    config_path=$(get_global_config_path)
    scope_name="global"
  else
    config_path=$(get_project_config_path)
    scope_name="project-local"
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$config_path")"

  # Create config file if it doesn't exist
  touch "$config_path"

  # Check if key already exists
  if grep -F "$key=" "$config_path" 2>/dev/null | grep -q "^$key="; then
    # Update existing key (escape special chars for sed)
    escaped_key=$(printf '%s\n' "$key" | sed 's/[.[\*^$]/\\&/g')
    if [ "$(uname)" = "Darwin" ]; then
      sed -i '' "s|^$escaped_key=.*|$key=$value|" "$config_path"
    else
      sed -i "s|^$escaped_key=.*|$key=$value|" "$config_path"
    fi
    echo "Updated $key=$value ($scope_name)"
  else
    # Add new key
    echo "$key=$value" >> "$config_path"
    echo "Set $key=$value ($scope_name)"
  fi
}

# Unset config value
# Usage: unset_config [--global|--project] <key>
unset_config() {
  scope="--project"  # Default to project-local

  # Parse scope flag
  case "$1" in
    --global)
      scope="--global"
      shift
      ;;
    --project)
      scope="--project"
      shift
      ;;
  esac

  key="$1"

  if [ -z "$key" ]; then
    echo "Error: must specify config key" >&2
    echo "Usage: todos config unset [--global|--project] <key>" >&2
    return 1
  fi

  # Determine target config file
  if [ "$scope" = "--global" ]; then
    config_path=$(get_global_config_path)
    scope_name="global"
  else
    config_path=$(get_project_config_path)
    scope_name="project-local"
  fi

  if [ ! -f "$config_path" ]; then
    echo "Config key '$key' not found in $scope_name config" >&2
    return 1
  fi

  # Check if key exists
  if ! grep -F "$key=" "$config_path" 2>/dev/null | grep -q "^$key="; then
    echo "Config key '$key' not found in $scope_name config" >&2
    return 1
  fi

  # Remove the key (escape special chars for sed)
  escaped_key=$(printf '%s\n' "$key" | sed 's/[.[\*^$]/\\&/g')
  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' "/^$escaped_key=/d" "$config_path"
  else
    sed -i "/^$escaped_key=/d" "$config_path"
  fi

  echo "Unset $key ($scope_name)"
}

# List all configuration
list_config() {
  global_config=$(get_global_config_path)
  project_config=$(get_project_config_path)

  echo "Configuration Hierarchy:"
  echo "========================"
  echo ""

  # Show global config
  echo "Global config: $global_config"
  if [ -f "$global_config" ]; then
    cat "$global_config" | sed 's/^/  /'
  else
    echo "  (not set)"
  fi
  echo ""

  # Show project-local config
  echo "Project-local config: $project_config"
  if [ -f "$project_config" ]; then
    cat "$project_config" | sed 's/^/  /'
    echo "  (overrides global)"
  else
    echo "  (not set)"
  fi
  echo ""

  # Show effective configuration (merged)
  echo "Effective Configuration (merged):"
  echo "---------------------------------"

  # Collect all unique keys from both configs
  all_keys=""
  if [ -f "$global_config" ]; then
    all_keys="$all_keys $(grep '^[^#]' "$global_config" 2>/dev/null | cut -d= -f1)"
  fi
  if [ -f "$project_config" ]; then
    all_keys="$all_keys $(grep '^[^#]' "$project_config" 2>/dev/null | cut -d= -f1)"
  fi

  # Remove duplicates and display
  for key in $(echo "$all_keys" | tr ' ' '\n' | sort -u); do
    value=$(get_config "$key" 2>/dev/null)
    if [ $? -eq 0 ]; then
      # Determine source
      if [ -f "$project_config" ] && grep -F "$key=" "$project_config" 2>/dev/null | grep -q "^$key="; then
        source="project"
      else
        source="global"
      fi
      printf "  %-30s = %-20s [%s]\n" "$key" "$value" "$source"
    fi
  done

  if [ -z "$all_keys" ]; then
    echo "  (no configuration set)"
  fi

  echo ""
  echo "Supported Configuration Keys:"
  echo "-----------------------------"
  echo ""
  echo "List settings:"
  echo "  list.default_sort           - Default sort field (priority, due_date, created_at, etc.)"
  echo "  list.show_completed         - Show completed tasks by default (true/false)"
  echo ""
  echo "Create settings:"
  echo "  create.default_priority     - Default priority for new tasks (1-26, where 1=A)"
  echo "  create.default_status       - Default status for new tasks (TODO, IN_PROGRESS, DONE)"
  echo "  create.auto_assign_to_me    - Auto-assign created tasks to you (true/false)"
  echo ""
  echo "Build settings:"
  echo "  build.auto_assign           - Auto-assign discovered tasks to you (true/false)"
  echo "  build.scan_paths            - Default paths to scan (comma-separated)"
  echo "  build.default_from          - Default scan mode (auto, comments, todo-files, all)"
  echo ""
  echo "Usage:"
  echo "  todos config set <key> <value>           # Set project-local config"
  echo "  todos config set --global <key> <value>  # Set global config"
  echo "  todos config get <key>                   # Get effective value"
  echo "  todos config unset <key>                 # Unset project-local config"
  echo "  todos config unset --global <key>        # Unset global config"
  echo "  todos config list                        # Show all configs"
}
