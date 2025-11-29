#!/bin/sh
# config management library for user settings

get_config_path() {
  # Check for config file in order of precedence
  if [ -f "$HOME/.config/todos/config" ]; then
    echo "$HOME/.config/todos/config"
  elif [ -f "$HOME/.todosrc" ]; then
    echo "$HOME/.todosrc"
  else
    # Default location
    mkdir -p "$HOME/.config/todos"
    echo "$HOME/.config/todos/config"
  fi
}

get_config() {
  # Get a config value
  config_path=$(get_config_path)
  key="$1"

  if [ -z "$key" ]; then
    # No key specified, show all config
    if [ -f "$config_path" ]; then
      cat "$config_path"
    else
      echo "No configuration file found"
    fi
    return 0
  fi

  if [ ! -f "$config_path" ]; then
    echo "Config key '$key' not set"
    return 1
  fi

  # Get value for specific key
  value=$(grep "^$key=" "$config_path" | cut -d= -f2-)

  if [ -z "$value" ]; then
    echo "Config key '$key' not set"
    return 1
  fi

  echo "$value"
}

set_config() {
  # Set a config value
  config_path=$(get_config_path)
  key="$1"
  value="$2"

  if [ -z "$key" ]; then
    echo "Error: must specify config key"
    return 1
  fi

  if [ -z "$value" ]; then
    echo "Error: must specify config value"
    return 1
  fi

  # Create config file if it doesn't exist
  touch "$config_path"

  # Check if key already exists
  if grep -q "^$key=" "$config_path"; then
    # Update existing key
    # Use different sed syntax for macOS vs Linux
    if [ "$(uname)" = "Darwin" ]; then
      sed -i '' "s|^$key=.*|$key=$value|" "$config_path"
    else
      sed -i "s|^$key=.*|$key=$value|" "$config_path"
    fi
    echo "Updated $key=$value"
  else
    # Add new key
    echo "$key=$value" >> "$config_path"
    echo "Set $key=$value"
  fi
}

unset_config() {
  # Remove a config value
  config_path=$(get_config_path)
  key="$1"

  if [ -z "$key" ]; then
    echo "Error: must specify config key"
    return 1
  fi

  if [ ! -f "$config_path" ]; then
    echo "Config key '$key' not found"
    return 1
  fi

  # Check if key exists
  if ! grep -q "^$key=" "$config_path"; then
    echo "Config key '$key' not found"
    return 1
  fi

  # Remove the key
  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' "/^$key=/d" "$config_path"
  else
    sed -i "/^$key=/d" "$config_path"
  fi

  echo "Unset $key"
}

list_config() {
  # List all configuration with descriptions
  config_path=$(get_config_path)

  echo "Configuration file: $config_path"
  echo ""
  echo "Available configuration keys:"
  echo "  DB                 - Path to the SQLite database file"
  echo "  MIN_PRIORITY       - Minimum priority level to show (1=A, 2=B, etc.)"
  echo "  MAX_PRIORITY       - Maximum priority level to show"
  echo "  DEFAULT_STATUS     - Default status for new tasks (TODO, IN_PROGRESS, DONE)"
  echo "  DATE_FORMAT        - Date format for display (not yet implemented)"
  echo ""

  if [ -f "$config_path" ]; then
    echo "Current configuration:"
    cat "$config_path"
  else
    echo "No configuration file found. Use 'set' to create one."
  fi
}
