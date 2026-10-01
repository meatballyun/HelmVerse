#!/bin/bash
# ./scripts/kind/uninstall_kind.sh
#
# This script uninstalls the "kind" Kubernetes tool installed locally at $HOME/.local/bin.
#
# Features:
# - Safely removes the kind binary if it exists.
# - Cleans up PATH modifications in ~/.bashrc (and optionally ~/.zshrc in future improvements).
# - Verifies it's running inside a git repository to maintain project context.
#
# Requirements:
# - Must be executed from within a git-tracked project directory.
# - Assumes ~/.bashrc contains the export line adding $HOME/.local/bin to PATH.
#
# Usage:
#   ./scripts/kind/uninstall_kind.sh
#
# Notes:
# - After running, restart your shell or source your profile (e.g., `source ~/.bashrc`)
#   to fully apply PATH changes.
# - Designed for macOS and Linux environments.

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

# Define the installation path and binary location
KIND_BINARY="$HOME/.local/bin/kind"
KIND_PATH="$HOME/.local/bin"

# Check if kind is installed
if [[ -f "$KIND_BINARY" ]]; then
  # Remove the kind binary
  echo "Removing kind binary..."
  rm -f "$KIND_BINARY"
else
  info "Kind is not installed. No action needed."
  exit 0
fi

# Remove kind from PATH by modifying .bashrc and .zshrc if present
echo "Removing kind from PATH..."
if [[ -f "$HOME/.bashrc" ]]; then
  if grep -q "$KIND_PATH" "$HOME/.bashrc"; then
    sed -i '/.local\/bin/d' "$HOME/.bashrc"
    success "Removed $HOME/.local/bin from .bashrc"
  else
    warn "$HOME/.local/bin not found in .bashrc"
  fi
fi

# Suggest restarting the shell
success "Please restart your shell or run 'source ~/.bashrc' or 'source ~/.zshrc' to apply changes."
