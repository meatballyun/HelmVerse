#!/bin/bash
# ./scripts/kubectl/check_kubectl.sh

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
source "$ROOT_DIR/utils/logger.sh"

# Check if Kubectl is already installed
echo "Checking Kubectl Installation ..."
if command -v kubectl &> /dev/null; then
  KUBECTL_VERSION=$(kubectl version --client)
  success "Kubectl is already installed: $KUBECTL_VERSION"
  exit 0
else
  info "Kubectl is not installed."
  exit 1
fi
