#!/bin/sh
# Shared uninstall implementation
# This file contains the core uninstall logic used by both:
# - 'todos uninstall' subcommand
# - standalone uninstall.sh script

perform_uninstall() {
  dry_run="$1"

  # Color output
  if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
  else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
  fi

  if [ "$dry_run" = "true" ]; then
    printf "${BLUE}DRY RUN MODE - No files will be removed${NC}\n\n"
  fi

  printf "Uninstalling todos task management tool...\n\n"

  # Default installation directories
  DEFAULT_BIN="${HOME}/.local/bin"
  DEFAULT_LIB="${HOME}/.local/lib/todos"
  DEFAULT_SHARE="${HOME}/.local/share/todos"
  MANIFEST="${DEFAULT_SHARE}/manifest"

  # Try to read manifest
  if [ -f "$MANIFEST" ]; then
    printf "${GREEN}✓${NC} Found installation manifest\n"

    # Read installation directories from manifest
    INSTALL_BIN=$(grep "^INSTALL_BIN=" "$MANIFEST" | cut -d= -f2)
    INSTALL_LIB=$(grep "^INSTALL_LIB=" "$MANIFEST" | cut -d= -f2)
    INSTALL_SHARE=$(grep "^INSTALL_SHARE=" "$MANIFEST" | cut -d= -f2)

    # Default to standard paths if not found in manifest
    INSTALL_BIN="${INSTALL_BIN:-$DEFAULT_BIN}"
    INSTALL_LIB="${INSTALL_LIB:-$DEFAULT_LIB}"
    INSTALL_SHARE="${INSTALL_SHARE:-$DEFAULT_SHARE}"
  else
    printf "${YELLOW}!${NC} Manifest not found, using default paths\n"
    INSTALL_BIN="$DEFAULT_BIN"
    INSTALL_LIB="$DEFAULT_LIB"
    INSTALL_SHARE="$DEFAULT_SHARE"
  fi

  # Check what exists
  found_something=false

  if [ -f "$INSTALL_BIN/todos" ]; then
    printf "Found executable: ${INSTALL_BIN}/todos\n"
    found_something=true
  fi

  if [ -d "$INSTALL_LIB" ]; then
    printf "Found library directory: ${INSTALL_LIB}\n"
    found_something=true
  fi

  if [ -d "$INSTALL_SHARE" ]; then
    printf "Found data directory: ${INSTALL_SHARE}\n"
    found_something=true
  fi

  if [ "$found_something" = false ]; then
    printf "${YELLOW}No installation found.${NC}\n"
    return 0
  fi

  # Confirm uninstall (skip in dry-run mode)
  if [ "$dry_run" != "true" ]; then
    printf "\n${YELLOW}This will remove todos executable and libraries.${NC}\n"
    printf "Continue? [y/N]: "
    read -r confirm
    confirm=$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')

    if [ "$confirm" != 'y' ] && [ "$confirm" != 'yes' ]; then
      printf "Uninstall cancelled.\n"
      return 0
    fi
  fi

  # Remove files and directories
  printf "\nRemoving files...\n"

  if [ -f "$INSTALL_BIN/todos" ]; then
    if [ "$dry_run" = "true" ]; then
      printf "${BLUE}[DRY RUN]${NC} Would remove ${INSTALL_BIN}/todos\n"
    else
      rm -f "$INSTALL_BIN/todos"
      printf "${GREEN}✓${NC} Removed ${INSTALL_BIN}/todos\n"
    fi
  fi

  if [ -d "$INSTALL_LIB" ]; then
    if [ "$dry_run" = "true" ]; then
      printf "${BLUE}[DRY RUN]${NC} Would remove ${INSTALL_LIB}\n"
    else
      rm -rf "$INSTALL_LIB"
      printf "${GREEN}✓${NC} Removed ${INSTALL_LIB}\n"
    fi
  fi

  if [ -d "$INSTALL_SHARE" ]; then
    if [ "$dry_run" = "true" ]; then
      printf "${BLUE}[DRY RUN]${NC} Would remove ${INSTALL_SHARE}\n"
    else
      rm -rf "$INSTALL_SHARE"
      printf "${GREEN}✓${NC} Removed ${INSTALL_SHARE}\n"
    fi
  fi

  if [ "$dry_run" = "true" ]; then
    printf "\n${BLUE}DRY RUN COMPLETE - No changes made${NC}\n"
  else
    printf "\n${GREEN}Uninstall complete!${NC}\n"
  fi

  printf "\nNote: Project databases (.todos.db files) in your projects are untouched.\n"

  if [ "$dry_run" != "true" ]; then
    printf "\nNote: If you added ${INSTALL_BIN} to your PATH,\n"
    printf "you may want to remove that from your shell config.\n"
  fi
}
