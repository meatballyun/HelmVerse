#!/usr/bin/env bash
# ./scripts/kind/create_namespace.sh
#
# Purpose:
#   Create a Kubernetes namespace based on the given project name if it doesn't exist.
#
# Usage:
#   ./scripts/create_namespace.sh <project_name>
#   Example: ./scripts/create_namespace.sh my-backend

# With strict mode for safer scripting
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory using Git (preferred method)
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

# Exit with error if script is not run inside a Git repository
if [ -z "$ROOT_DIR" ]; then
  error "Failed to detect project root. Make sure you're running inside a git repository." >&2
  exit 1
fi

# Load utility scripts providing reusable functions
source "$ROOT_DIR/utils/logger.sh"

# Check if project name argument is provided
if [ $# -ne 1 ]; then
  echo "[ERROR] Please provide a project name (namespace). Usage: ./scripts/create_namespace.sh <project_name>"
  exit 1
fi

# Get project name (namespace)
PROJECT_NAME=$1

# Check if namespace already exists
if kubectl get namespace "$PROJECT_NAME" &>/dev/null; then
  warn "⚠️  Namespace '$PROJECT_NAME' already exists."
else
  # Create namespace using kubectl
  info "🔨 Creating namespace: $PROJECT_NAME"
  kubectl create namespace "$PROJECT_NAME"

  success "✅ Namespace '$PROJECT_NAME' created successfully!"
fi
