#!/bin/bash
# ./utils/menu_utils.sh
#
# Purpose:
#   Shell utilities for interactive user selections in scripts.
#   Provides functions to display options or folder lists and let users choose.
#   Useful for deployment scripts, maintenance tools, and CI/CD pipelines that require human confirmation or choice.
#
# Usage examples:
#   selected=$(select_option "Choose a service" "api" "web" "worker")
#   selected_folder=$(select_folder "../projects")
#
# Functions provided:
#   - select_option      Display a list of options and prompt user to select one (supports cancel option)
#   - select_folder      List folders under given base directory and prompt user to select one
#
# Features:
#   - Uses colored logger utilities for better readability and user feedback
#   - Input validation: prevents invalid selections
#   - Supports cancel action by typing 'q' or 'Q'
#
# Arguments:
#   select_option:
#     <prompt>           Message to display before listing options
#     <option1> [option2 ...]  List of options to choose from
#
#   select_folder:
#     <base_dir>         Directory path where folders will be listed for selection
#
# Dependencies:
#   - utils/logger.sh    (for logging: info, success, warn, error, headline, note)
#   - utils/list_utils.sh (for list_folders function used in select_folder)
#
# Notes:
#   - Selected value is echoed to stdout, allowing assignment with command substitution
#   - If user cancels, select_option returns with status 1

# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Source logging functions for output messages (info, error, success)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

# List all folders under a given base directory
list_folders() {
  local base_dir="$1"

  if [ -z "$base_dir" ] || [ ! -d "$base_dir" ]; then
    die "Invalid or missing base directory: $base_dir"
  fi

  find "$base_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}

# Simple yes/no confirmation (returns 0 for yes, 1 for no)
confirm() {
  local prompt="$1"
  while true; do
    read -p "$(echo -e "${CYAN}$prompt [y/n]: ${COLOR_RESET}")" yn
    case $yn in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
  done
}

# Present a list of options and return the selected one
# Returns 0 if user selected, 1 if cancelled
select_option() {
  local options=("$@")

  if [ ${#options[@]} -eq 0 ]; then
    die "No options provided for selection."
  fi

  for i in "${!options[@]}"; do
    echo -e "  $((i+1))) ${options[$i]}"
  done
  echo -e "  ${PURPLE}q) Cancel"

  while true; do

    echo -ne "${CYAN}Enter choice (1-${#options[@]} or q): ${COLOR_RESET}"
    read choice
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
      note "Selection cancelled by user."
      return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
      success "You selected: ${options[$((choice-1))]}"
      SELECTED_OPTION="${options[$((choice-1))]}"
      return 0
    else
      warn "Invalid selection. Please try again."
    fi
  done
}

# Select folder and return either name or full path
# Returns 0 if selected, 1 if cancelled
select_folder() {
  local base_dir="$1"
  local folders=($(list_folders "$base_dir"))

  if [ ${#folders[@]} -eq 0 ]; then
    die "No folders found in $base_dir"
  fi

  select_option ${folders[@]}
  SELECTED_FOLDER="${SELECTED_OPTION}"
}
