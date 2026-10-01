#!/bin/bash
# ./scripts/helm/install_helm.sh
#
# This script automates the installation of a specific version of Helm (v3) in the local environment.
#
# Features:
# - Downloads the official Helm installer script.
# - Installs the specified Helm version.
# - Uses project-wide logger utilities for colored, structured output.
# - Validates execution inside a git repository for context safety.
#
# Usage:
#   ./scripts/helm/install_helm.sh
#
# Notes:
# - After successful install, Helm will be available in your PATH.
# - Designed for macOS and Linux environments.
# - Requires curl and git to be installed.
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
source "$ROOT_DIR/utils/env.sh"

echo "Starting Helm Installation Script"

# Define the desired Helm version
load_env "$ROOT_DIR/.env"

if [ -z "$HELM_VERSION" ]; then
  HELM_VERSION="$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
else
  # Ensure version starts with 'v'
  if [[ "$HELM_VERSION" != v* ]]; then
    HELM_VERSION="v$HELM_VERSION"
  fi
fi

info "Target Helm version: $HELM_VERSION"

# Download the Helm installation script
echo "Downloading Helm Installer"
if curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3; then
  success "Helm installer script downloaded successfully."
else
  die "Failed to download Helm installer script."
fi

# Make the script executable
info "Making installer script executable..."
chmod 700 get_helm.sh
success "Installer script is now executable."

# Install Helm with the specified version
echo "Installing Helm $HELM_VERSION"
if ./get_helm.sh --version $HELM_VERSION; then
  success "Helm $HELM_VERSION installed successfully."
else
  die "Helm installation failed."
fi

# Remove the installation script after completion
echo "Cleaning Up"
rm get_helm.sh
success "Installer script removed."

# Verify the installation
echo "Verifying Helm Installation"
if helm version; then
  success "Helm is installed and working!"
else
  die "Helm verification failed. Please check your installation."
fi

success "Helm installation script completed successfully!"
