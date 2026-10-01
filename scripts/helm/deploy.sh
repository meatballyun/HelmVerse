#!/bin/bash
# ./script/helm/deploy.sh

# With strict mode for safer scripting
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory using Git (preferred method)
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

# Exit with error if script is not run inside a Git repository
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

# Default: no project specified
PROJECT_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      if [[ -n "${2:-}" ]]; then
        PROJECT_NAME="$2"
        shift 2
      else
        error "Option '$1' requires an argument."
        exit 1
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [-p|--project <project_name>]"
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# If no project name provided, show selection menu
if [ -z "$PROJECT_NAME" ]; then
  select_folder "$PROJECTS_DIR"
  if [ -n "$SELECTED_FOLDER" ]; then
    PROJECT_NAME="$SELECTED_FOLDER"
  else
    error "No project selected."
    exit 1
  fi
fi

# Define full helm-chart path of the selected project
CHART_PATH="${PROJECTS_DIR}/${PROJECT_NAME}/helm-chart"
DEPLOY_SCRIPT="${CHART_PATH}/deploy.sh"

echo "🚀 Start deploying $PROJECT_NAME..."

# Check if project-specific deploy script exists
if [ ! -f "$DEPLOY_SCRIPT" ]; then
  error "Deploy script not found: $DEPLOY_SCRIPT"
  error "Please create a deploy.sh script in the helm-chart directory."
  exit 1
fi

# Execute project-specific deploy script
cd "$CHART_PATH"
bash "$DEPLOY_SCRIPT"

success "✅ $PROJECT_NAME deployed successfully "
