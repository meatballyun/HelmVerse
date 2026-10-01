#!/bin/bash
# ./scripts/helm/uninstall_helm.sh
#
# This script automates the uninstallation of Helm (v3) from the local environment.
#
# Features:
# - Detects and removes the Helm binary.
# - Cleans up related cache and config directories.
# - Uses project-wide logger utilities for colored, structured output.
# - Validates execution inside a git repository for context safety.
#
# Usage:
#   ./scripts/helm/uninstall_helm.sh
#
# Notes:
# - Designed for macOS and Linux environments.
# - Safe to run multiple times (idempotent).
#

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

echo "Starting Helm Uninstallation Script"

# Check if helm is installed
if command -v helm &> /dev/null; then
  HELM_PATH=$(command -v helm)
  info "Detected Helm at: $HELM_PATH"
else
  warn "Helm is not installed or not found in PATH. Skipping binary removal."
  HELM_PATH=""
fi

# Remove Helm binary if detected
if [ -n "$HELM_PATH" ] && [ -f "$HELM_PATH" ]; then
  echo "Removing Helm Binary"
  if sudo rm -f "$HELM_PATH"; then
    success "Helm binary removed from $HELM_PATH"
  else
    die "Failed to remove Helm binary."
  fi
else
  info "No Helm binary found to remove."
fi

# Clean up Helm config and cache (optional but recommended)
echo "Cleaning Up Helm Config and Cache"

HELM_CONFIG_DIR="$HOME/.config/helm"
HELM_CACHE_DIR="$HOME/.cache/helm"
HELM_DATA_DIR="$HOME/.local/share/helm"

# Remove config
if [ -d "$HELM_CONFIG_DIR" ]; then
  rm -rf "$HELM_CONFIG_DIR"
  success "Removed Helm config directory: $HELM_CONFIG_DIR"
else
  info "Helm config directory not found. Skipping."
fi

# Remove cache
if [ -d "$HELM_CACHE_DIR" ]; then
  rm -rf "$HELM_CACHE_DIR"
  success "Removed Helm cache directory: $HELM_CACHE_DIR"
else
  info "Helm cache directory not found. Skipping."
fi

# Remove data
if [ -d "$HELM_DATA_DIR" ]; then
  rm -rf "$HELM_DATA_DIR"
  success "Removed Helm data directory: $HELM_DATA_DIR"
else
  info "Helm data directory not found. Skipping."
fi

# Verify uninstallation
echo "Verifying Helm Removal"
if ! command -v helm &> /dev/null; then
  success "Helm has been uninstalled successfully!"
else
  warn "Helm command still detected in PATH. You may need to check your PATH or manually remove leftover binaries."
fi

success "Helm uninstallation script completed successfully!"
