#!/bin/bash
# ./scripts/kind/check_kind.sh

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
echo "Checking Kind Installation ..."
if command -v kind &> /dev/null; then
  KIND_VERSION=$(kind --version)
  success "Kind is already installed: $KIND_VERSION"
  exit 0
else
  info "Kind is not installed."
  exit 1
fi
