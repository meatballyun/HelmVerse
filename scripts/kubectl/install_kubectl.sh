#!/bin/bash
# ./script/kubectl/install_kubectl.sh
#
# This script checks if `kubectl` (Kubernetes CLI) is installed and installs it if missing.
#
# Features:
# - Detects project root via Git.
# - Uses project-level logger utilities for consistent output.
# - Downloads the latest stable kubectl binary (Linux amd64).
# - Installs kubectl to ~/.local/bin (user space, no root required).
# - Adds ~/.local/bin to PATH in .bashrc if missing.
# - Supports Ubuntu and Linux-based systems.
#
# Intended for DevOps engineers setting up Kubernetes tooling
# inside project environments managed via Git.
#
# Notes:
# - After installation, restart your terminal or run `source ~/.bashrc` to refresh PATH.
# - For macOS support, adapt the download URL accordingly.

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

# Load utility scripts providing reusable functions (info, error, etc.)
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/env.sh"

# Check if kubectl is installed
info "Checking if kubectl is already installed..."
if command -v kubectl &> /dev/null; then
  KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "Unknown version")
  info "kubectl is already installed: $KUBECTL_VERSION"
  exit 0
else
  info "kubectl is not installed. Proceeding with installation..."
fi

# Download the latest kubectl (Linux amd64 version)
load_env "$ROOT_DIR/.env"

if [ -z "$KUBECTL_VERSION" ]; then
  KUBECTL_VERSION="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
else
  # Ensure version starts with 'v'
  if [[ "$KUBECTL_VERSION" != v* ]]; then
    KUBECTL_VERSION="v$KUBECTL_VERSION"
  fi
fi

info "Downloading kubectl version $KUBECTL_VERSION..."
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"

# Make it executable
chmod +x ./kubectl

# Move to ~/.local/bin (user space)
mkdir -p "$HOME/.local/bin"
mv ./kubectl "$HOME/.local/bin/"

# Export PATH immediately for current shell session
export PATH="$HOME/.local/bin:$PATH"

# Ensure ~/.local/bin is in PATH (for future terminal sessions)
if ! grep -q 'PATH=.*$HOME/.local/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  info "Added ~/.local/bin to PATH in .bashrc"
fi


info "kubectl installed successfully!"
kubectl version --client --output=yaml

success "✅ Done! Please restart your terminal or run 'source ~/.bashrc' to ensure PATH changes take effect."
