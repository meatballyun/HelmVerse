#!/bin/bash
# ./script/gitops/init_gitops.sh
#
# This script initializes a GitOps setup for a selected project.
#
# Features:
# - Detects project root via Git.
# - Allows user to select a project folder (if PROJECT_NAME not already set).
# - Loads existing environment configuration (if any).
# - Prompts user to input Git repository details.
# - Saves repository info to a .env file.
# - Clones the selected Git repository into the project folder.
#
# Intended for DevOps teams managing multiple projects with GitOps workflow.
# Make sure this script is run inside a valid Git repository structure.
#
# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory using Git
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

# Exit if not inside a Git repository (enforces script to be project-bound)
if [ -z "$ROOT_DIR" ]; then
  echo "[ERROR] Failed to detect project root. Make sure you're running inside a git repository." >&2
  exit 1
fi

# Load utility scripts providing reusable functions
source "$ROOT_DIR/utils/clone_git_repo.sh"
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/menu_utils.sh"
source "$ROOT_DIR/utils/env.sh"

# Set the path to the projects directory
PROJECTS_DIR="$ROOT_DIR/projects"

# If PROJECT_NAME is not already set by the calling script, prompt for selection
if [ -z "$PROJECT_NAME" ]; then
  info "No project name provided. Please select a project for GitOps initialization:"
  select_folder "$PROJECTS_DIR"
  if [ -n "$SELECTED_FOLDER" ]; then
    PROJECT_NAME="$SELECTED_FOLDER"
  else
    error "No project selected. GitOps initialization cancelled."
    exit 1
  fi
else
  info "Using project '$PROJECT_NAME' for GitOps initialization (already selected)."
fi

# Define full path of the selected project
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

# Check if project.env file exists
if [ -f "$PROJECT_DIR/project.env" ]; then
  info "project.env file exists in $PROJECT_DIR"

  read -r -p "$(echo -e "${CYAN}Do you want to load environment variables from this file? [Y/n]: ${COLOR_RESET}")" -e -i "Y" yn_load
  if [[ "$yn_load" =~ ^[Yy]$ || -z "$yn_load" ]]; then # Assume 'y' if empty or 'Y/y'
    load_env "${PROJECT_DIR}/project.env"
    IS_LOAD_ENV=true
  else
    read -r -p "$(echo -e "${CYAN}Initializing will remove the project.env file. Do you want to proceed? [y/N]: ${COLOR_RESET}")" -e -i "N" yn_delete
    if [[ "$yn_delete" =~ ^[Yy]$ ]]; then
      rm -f "${PROJECT_DIR}/project.env"
      success "project.env has been removed."
    else
      warn "Operation canceled by user."
      exit 1
    fi
  fi
fi

# Prompt user for Git repository URL if not already loaded from env
if [ -z "$GIT_REPO_URL" ]; then
  read -p "$(echo -e "${BLUE}Please enter the GIT repository URL:${COLOR_RESET} ")" git_repo_url
  GIT_REPO_URL="$git_repo_url"
fi

# Prompt user for Git repository branch if not already loaded from env
if [ -z "$GIT_REPO_BRANCH" ]; then
  read -p "$(echo -e "${BLUE}Please enter the GIT repository branch:${COLOR_RESET} ")" git_repo_branch
  GIT_REPO_BRANCH="$git_repo_branch"
fi

# Prompt user for Git repository name if not already loaded from env
if [ -z "$GIT_REPO_NAME" ]; then
  read -p "$(echo -e "${BLUE}Please enter the GIT repository name:${COLOR_RESET} ")" git_repo_name
  GIT_REPO_NAME="$git_repo_name"
fi

# Save Git repo info into project.env
if [ -z "$IS_LOAD_ENV" ]; then
  export_env_to_file "$PROJECT_DIR/project.env" GIT_REPO_URL GIT_REPO_BRANCH GIT_REPO_NAME
else
  export_env_to_file_append "$PROJECT_DIR/project.env" GIT_REPO_URL GIT_REPO_BRANCH GIT_REPO_NAME
fi

# Clone the selected Git repository into the project directory
clone_project "$PROJECT_DIR" "$GIT_REPO_URL" "$GIT_REPO_BRANCH" "$GIT_REPO_NAME"
