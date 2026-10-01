#!/bin/bash

# Safer scripting mode
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
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/menu_utils.sh"

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

info "🚀 Starting cleanup for Helm release: $PROJECT_NAME"

# Uninstall the Helm release (removes Deployments, Services, Ingress, etc.)
helm uninstall "$PROJECT_NAME"

success "✅ Helm release '$PROJECT_NAME' has been uninstalled."

# Sleep for a few seconds to ensure Kubernetes resources are released
sleep 5

info "🔎 Checking for leftover PersistentVolumeClaims (PVCs)..."
# Delete PVCs related to the release
kubectl get pvc | grep "$PROJECT_NAME" | awk '{print $1}' | xargs -r kubectl delete pvc
success "✅ PVCs cleaned up."

info "🔎 Checking for leftover ConfigMaps..."
# Delete ConfigMaps related to the release
kubectl get configmap | grep "$PROJECT_NAME" | awk '{print $1}' | xargs -r kubectl delete configmap
success "✅ ConfigMaps cleaned up."

info "🔎 Checking for leftover Secrets..."
# Delete Secrets related to the release
kubectl get secret | grep "$PROJECT_NAME" | awk '{print $1}' | xargs -r kubectl delete secret
success "✅ Secrets cleaned up."

success "🧹 Cleanup completed successfully!"
