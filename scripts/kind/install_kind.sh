#!/bin/bash
# ./scripts/kind/install_kind.sh
#
# This script installs the specified version of Kind (Kubernetes in Docker).
#
# Features:
# - Detects the operating system (Linux or macOS) and CPU architecture (amd64 or arm64).
# - Downloads the appropriate Kind binary from the official Kind releases.
# - Installs the Kind binary to the user's local bin directory (~/.local/bin).
# - Ensures the binary is executable and accessible in the current shell session.
# - Updates the ~/.bashrc file (Linux only) to permanently include the installation path for future sessions.
#
# Intended for developers and DevOps engineers who need to install Kind locally for Kubernetes cluster management.
# Ensure you're running this script in a compatible environment (Linux or macOS).
#
# Important Notes:
# - The script adds ~/.local/bin to your PATH for the current session.
# - On Linux, the script ensures that ~/.local/bin is added to ~/.bashrc for future terminal sessions.
# - On macOS, you'll need to manually add the export line to your shell profile (e.g., .bash_profile or .zshrc).
#
# The script will also verify the installation by checking the version of Kind after the installation process.
#
# Usage:
# - Run this script in a compatible shell environment to install the desired version of Kind.

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

# Define the version of kind to install
load_env "$ROOT_DIR/.env"

if [ -z "$KIND_VERSION" ]; then
  KIND_VERSION="$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
else
  # Ensure version starts with 'v'
  if [[ "$KIND_VERSION" != v* ]]; then
    KIND_VERSION="v$KIND_VERSION"
  fi
fi

info "Target Helm version: $KIND_VERSION"

# Detect OS type (linux or darwin)
OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"

# Detect CPU architecture (amd64 or arm64)
ARCH_TYPE="$(uname -m)"
if [[ "$ARCH_TYPE" == "x86_64" ]]; then
  ARCH_TYPE="amd64"
elif [[ "$ARCH_TYPE" == "arm64" || "$ARCH_TYPE" == "aarch64" ]]; then
  ARCH_TYPE="arm64"
else
  die "Unsupported architecture: $ARCH_TYPE"
fi

echo "Installing kind version $KIND_VERSION for $OS_TYPE-$ARCH_TYPE..."

# Create local bin directory if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Download the correct kind binary
curl -Lo "$HOME/.local/bin/kind" "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-${OS_TYPE}-${ARCH_TYPE}"

# Make the kind binary executable
chmod +x "$HOME/.local/bin/kind"

if [[ "$OS_TYPE" == "linux" ]]; then
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    info "Added ~/.local/bin to PATH in ~/.bashrc"
  fi
else
  # macOS
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    info "Added ~/.local/bin to PATH in ~/.zshrc"
  fi
fi

# Verify the installation by checking the version
echo "Verifying kind installation..."
"$HOME/.local/bin/kind" --version

success "Kind installation completed successfully!"
