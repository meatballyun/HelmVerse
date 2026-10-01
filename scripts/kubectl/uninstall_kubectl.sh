#!/bin/bash
# ./script/kubectl/uninstall_kubectl.sh
#
# This script uninstalls `kubectl` (Kubernetes CLI) from the user environment.
#
# Features:
# - Detects project root via Git.
# - Uses project-level logger utilities for consistent output.
# - Removes kubectl binary from ~/.local/bin.
# - Cleans up PATH export line from .bashrc (Ubuntu/Linux) or .zshrc (macOS).
#
# Intended for DevOps engineers cleaning up Kubernetes tooling
# inside project environments managed via Git.

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

# Load logger utilities
source "$ROOT_DIR/utils/logger.sh"

info "Starting kubectl uninstallation..."

# Remove kubectl binary
if [ -f "$HOME/.local/bin/kubectl" ]; then
  rm -f "$HOME/.local/bin/kubectl"
  success "Removed kubectl binary from ~/.local/bin"
else
  warn "kubectl binary not found in ~/.local/bin (already removed?)"
fi

# Detect OS (darwin for macOS, linux for Ubuntu)
OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"

# Backup .bashrc or .zshrc
if [[ "$OS_TYPE" == "darwin" ]]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

if [ -f "$SHELL_RC" ]; then
  cp "$SHELL_RC" "${SHELL_RC}.bak"
  info "Backed up $SHELL_RC to ${SHELL_RC}.bak"

  # Remove PATH export line (macOS sed needs '' for inline edit)
  if [[ "$OS_TYPE" == "darwin" ]]; then
    sed -i '' '/export PATH=.*\$HOME\/.local\/bin/d' "$SHELL_RC"
  else
    sed -i '/export PATH=.*\$HOME\/.local\/bin/d' "$SHELL_RC"
  fi

  success "Removed PATH export line from $SHELL_RC"
else
  warn "$SHELL_RC not found, skipped PATH cleanup"
fi

success "kubectl uninstallation completed!"
info "Please restart your terminal or run 'source $SHELL_RC' to refresh your environment."
