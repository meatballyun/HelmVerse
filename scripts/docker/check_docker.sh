#!/bin/bash
# ./script/docker/checkout_docker.sh
#
# This script checks if Docker is properly installed in the current environment.
# Part of the project's Docker management toolset for development environments.
# Returns exit code 0 if Docker is installed, 1 otherwise.

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

# Load utility scripts for logging
source "$ROOT_DIR/utils/logger.sh"

# Check if Docker CLI or Docker Desktop is already installed
echo "Checking Docker Installation ..."
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version)
  success "Docker is already installed: $DOCKER_VERSION"
  exit 0
else
  info "Docker is not installed."
  exit 1
fi
