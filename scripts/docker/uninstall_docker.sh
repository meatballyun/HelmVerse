#!/bin/bash
# ./script/docker/uninstall_docker.sh
#
# This script uninstalls Docker Engine and Docker Desktop from supported Linux distributions and macOS.
#
# Features:
# - Detects OS type (Ubuntu, Debian, CentOS, RHEL, Fedora, macOS).
# - Removes Docker Engine, containerd, Docker Compose Plugin.
# - Removes Docker Desktop from macOS and cleans up configuration files.
#
# Intended for DevOps teams managing Docker environments across multiple platforms.
# Make sure this script is run with root or sudo privileges.
#
# Supported OS:
# - Ubuntu
# - Debian
# - CentOS / RHEL / Fedora
# - macOS (via Homebrew)

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

# Load utility scripts for logging and environment
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/menu_utils.sh"
source "$ROOT_DIR/utils/env.sh"

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
  info "Detected OS: macOS"
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  OS_VERSION=$VERSION_ID
  info "Detected OS: $OS $OS_VERSION"
else
  die "Cannot detect OS. This script supports Linux and macOS only."
fi

# Uninstall Docker on Ubuntu/Debian-based systems
uninstall_docker_ubuntu_debian() {
  echo "Uninstalling Docker on Ubuntu/Debian"

  info "Stopping Docker service..."
  sudo systemctl stop docker

  info "Removing Docker Engine, containerd, and Docker Compose plugin..."
  sudo apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  info "Removing Docker dependencies and configuration files..."
  sudo apt-get autoremove -y
  sudo apt-get clean

  info "Removing Docker group..."
  sudo deluser ${SUDO_USER:-$USER} docker || true

  info "Docker has been successfully uninstalled!"
}

# Uninstall Docker on CentOS/RHEL/Fedora
uninstall_docker_centos_rhel() {
  echo "Uninstalling Docker on CentOS/RHEL/Fedora"

  info "Stopping Docker service..."
  sudo systemctl stop docker

  info "Removing Docker Engine, containerd, and Docker Compose plugin..."
  sudo yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  info "Removing Docker dependencies and configuration files..."
  sudo yum autoremove -y

  info "Removing Docker group..."
  sudo deluser ${SUDO_USER:-$USER} docker || true

  info "Docker has been successfully uninstalled!"
}

# Uninstall Docker Desktop on macOS
uninstall_docker_macos() {
  echo "Uninstalling Docker Desktop on macOS"

  osascript -e 'quit app "Docker"'

  echo "Removing Docker application..."
  rm -rf /Applications/Docker.app

  echo "Removing Docker user data and settings..."
  rm -rf ~/Library/Application\ Support/Docker\ Desktop
  rm -rf ~/Library/Group\ Containers/group.com.docker
  rm -rf ~/Library/Preferences/com.docker.docker.plist
  rm -rf ~/Library/Saved\ Application\ State/com.electron.docker-frontend.savedState

  warn "Due to macOS protections (SIP), please manually delete:"
  warn "  ~/Library/Containers/com.docker.docker"
  note "Open Finder ➔ Go ➔ Go to Folder ➔ enter '~/Library/Containers' and remove 'com.docker.docker' manually."

  success "Docker Desktop files have been removed (except SIP-protected items)."
  note "Optionally, restart your Mac to finalize cleanup."
}


# Run uninstaller based on OS
case $OS in
  ubuntu|debian)
    uninstall_docker_ubuntu_debian
    ;;
  centos|rhel|fedora)
    uninstall_docker_centos_rhel
    ;;
  macos)
    uninstall_docker_macos
    ;;
  *)
    die "Unsupported OS: $OS. Supported: Ubuntu, Debian, CentOS/RHEL, Fedora, macOS"
    ;;
esac

# Verify Docker uninstallation
verify_uninstall() {
  echo "Verifying Docker Uninstallation"

  if command -v docker &> /dev/null; then
    die "Docker is still installed. Please check the above logs."
  else
    success "Docker has been successfully uninstalled!"
  fi
}

# Verify uninstallation
verify_uninstall
