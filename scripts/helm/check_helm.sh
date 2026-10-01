#!/bin/bash
# ./scripts/helm/check_helm.sh

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

# Check if Helm is already installed
echo "Checking Helm Installation ..."
if command -v helm &> /dev/null; then
  HELM_VERSION=$(helm --version)
  success "Helm is already installed: $HELM_VERSION"
  exit 0
else
  info "Helm is not installed."
  exit 1
fi
