#!/bin/sh
# Installation script for todos task management tool

set -e  # Exit on error

# Color output (optional, degrades gracefully)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'  # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  NC=''
fi

check_requirements() {
  if [ -z "$(command -v sqlite3)" ]; then
    printf "${RED}Error: SQLite 3 not found.${NC}\n" >&2
    printf "Please install SQLite 3 and try again.\n" >&2
    printf "\n"
    printf "macOS:   brew install sqlite3\n" >&2
    printf "Ubuntu:  sudo apt-get install sqlite3\n" >&2
    printf "Fedora:  sudo dnf install sqlite\n" >&2
    return 1
  fi
  return 0
}

main() {
  printf "Installing todos task management tool...\n"
  printf "Installation prefix: ${PREFIX:-$HOME/.local}\n\n"

  # Check requirements
  if ! check_requirements; then
    exit 1
  fi

  printf "${GREEN}✓${NC} SQLite 3 found\n"

  # Determine installation directories (respects PREFIX environment variable)
  PREFIX="${PREFIX:-$HOME/.local}"
  INSTALL_BIN="$PREFIX/bin"
  INSTALL_LIB="$PREFIX/lib/todos"
  INSTALL_SHARE="$PREFIX/share/todos"

  # Get script directory (where install.sh lives)
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

  # Create installation directories
  printf "Creating installation directories...\n"
  mkdir -p "$INSTALL_BIN"
  mkdir -p "$INSTALL_LIB"
  mkdir -p "$INSTALL_SHARE"

  # Initialize manifest file
  MANIFEST="$INSTALL_SHARE/manifest"
  cat > "$MANIFEST" <<MANIFEST_HEADER
# Todos installation manifest
# This file tracks what was installed for safe uninstallation
VERSION=0.1.0
INSTALLED_AT=$(date '+%Y-%m-%d %H:%M:%S')
INSTALL_BIN=$INSTALL_BIN
INSTALL_LIB=$INSTALL_LIB
INSTALL_SHARE=$INSTALL_SHARE
MANIFEST_HEADER

  # Copy library files
  printf "Installing library files to ${INSTALL_LIB}...\n"
  for lib_file in "$SCRIPT_DIR"/lib/*.sh; do
    if [ -f "$lib_file" ]; then
      cp "$lib_file" "$INSTALL_LIB/"
      filename=$(basename "$lib_file")
      printf "  - $filename\n"
      echo "FILE=$INSTALL_LIB/$filename" >> "$MANIFEST"
    fi
  done

  # Copy and modify the main executable
  printf "Installing executable to ${INSTALL_BIN}/todos...\n"

  # Create the installed version with hardcoded LIBDIR (based on PREFIX at install time)
  cat > "$INSTALL_BIN/todos" <<INSTALLED_TODOS
#!/bin/sh
LIBDIR="$INSTALL_LIB"

# Import libraries
. "\$LIBDIR/common.sh"
. "\$LIBDIR/db.sh"
. "\$LIBDIR/users.sh"
. "\$LIBDIR/tasks.sh"
INSTALLED_TODOS

  # Append everything after the library imports from the original
  tail -n +16 "$SCRIPT_DIR/bin/todos" >> "$INSTALL_BIN/todos"

  chmod +x "$INSTALL_BIN/todos"
  echo "FILE=$INSTALL_BIN/todos" >> "$MANIFEST"

  # Copy schema file if it exists
  if [ -f "$SCRIPT_DIR/share/schema.sql" ]; then
    printf "Installing schema to ${INSTALL_SHARE}...\n"
    cp "$SCRIPT_DIR/share/schema.sql" "$INSTALL_SHARE/"
    echo "FILE=$INSTALL_SHARE/schema.sql" >> "$MANIFEST"
  fi

  # Manifest tracks itself
  echo "FILE=$MANIFEST" >> "$MANIFEST"

  printf "Created installation manifest at ${MANIFEST}\n"

  printf "\n${GREEN}Installation complete!${NC}\n\n"

  # Check if ~/.local/bin is in PATH
  case ":$PATH:" in
    *":$INSTALL_BIN:"*)
      printf "${GREEN}✓${NC} ${INSTALL_BIN} is in your PATH\n"
      ;;
    *)
      printf "${YELLOW}!${NC} ${INSTALL_BIN} is not in your PATH\n"
      printf "\n"
      printf "Add this line to your ~/.bashrc, ~/.zshrc, or ~/.profile:\n"
      printf "  export PATH=\"${INSTALL_BIN}:\$PATH\"\n"
      printf "\n"
      printf "Then reload your shell or run:\n"
      printf "  source ~/.bashrc  # or ~/.zshrc\n"
      ;;
  esac

  printf "\nNext steps:\n"
  printf "  1. Navigate to your project directory\n"
  printf "  2. Initialize the database: ${GREEN}todos init${NC}\n"
  printf "  3. Create your first task: ${GREEN}todos create \"My first task\"${NC}\n"
  printf "\nNote: Each project has its own .todos.db and .todos.users.db databases.\n"
  printf "The databases will be created in the directory where you run 'todos init'.\n"
  printf "Users are automatically created on first command.\n"
}

main "$@"
