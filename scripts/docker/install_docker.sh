#!/bin/bash
# ./script/docker/install_docker.sh
#
# This script installs Docker Engine on supported Linux distributions and macOS.
#
# Features:
# - Detects OS type (Ubuntu, Debian, CentOS, RHEL, Fedora, macOS).
# - Checks if Docker is already installed before proceeding.
# - Installs Docker Engine, containerd, and Docker Compose Plugin.
# - Adds the current user to the docker group for non-root usage (Linux only).
# - Verifies Docker installation after completion.
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

# decide sudo usage for root-required commands
if [ "$EUID" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

TARGET_USER="${SUDO_USER-}"
if [ -z "${TARGET_USER}" ]; then
  TARGET_USER="$(id -un 2>/dev/null || true)"
fi
if [ -z "${TARGET_USER}" ]; then
  TARGET_USER="${USER-}"
fi

: "${TARGET_USER:=root}"

check_docker_installed() {
  if command -v docker >/dev/null 2>&1; then
    success "Docker already installed: $(docker --version)"
    exit 0
  else
    info "Docker is not installed."
  fi
}

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

check_docker_desktop_macos() {
  echo "Checking Docker Desktop Installation (macOS)"
  if [ -d "/Applications/Docker.app" ]; then
    success "Docker Desktop is already installed in Applications folder."
    exit 0
  else
    info "Docker Desktop is not installed. Proceeding with installation..."
  fi
}

# Call appropriate check function based on OS
case $OS in
  ubuntu|debian|centos|rhel|fedora)
    check_docker_installed
    ;;
  macos)
    check_docker_desktop_macos
    ;;
esac

# Install Docker on Ubuntu/Debian-based systems
install_docker_ubuntu_debian() {
  echo "Installing Docker on Ubuntu/Debian"

  info "Updating package lists..."
  $SUDO apt-get update

  info "Installing prerequisites..."
  $SUDO apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  info "Adding Docker's official GPG key..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  info "Setting up Docker repository..."
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

  info "Updating package lists with Docker repo..."
  $SUDO apt-get update

  info "Installing Docker Engine, containerd, and Docker Compose plugin..."
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  info "Enabling and starting docker service..."
  $SUDO systemctl enable --now docker

  # Add current user to docker group
  info "Adding user '$TARGET_USER' to the 'docker' group..."
  $SUDO usermod -aG docker "$TARGET_USER"
  warn "Relogin required to apply group membership. Run: newgrp docker"
}

# Install Docker on CentOS/RHEL/Fedora
install_docker_centos_rhel() {
  echo "Installing Docker on CentOS/RHEL/Fedora"

  info "Installing prerequisites..."
  $SUDO yum install -y yum-utils

  info "Setting up Docker repository..."
  $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

  info "Installing Docker Engine, containerd, and Docker Compose plugin..."
  $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  info "Starting Docker service..."
  $SUDO systemctl enable --now docker

  info "Adding user '$TARGET_USER' to the 'docker' group..."
  $SUDO usermod -aG docker "$TARGET_USER"
  warn "Relogin required to apply group membership. Run: newgrp docker"
}

# Install Docker Desktop on macOS
install_docker_macos() {
  echo "Installing Docker Desktop on macOS"

  # Install Homebrew if not present
  if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  info "Installing Docker Desktop..."
  brew install --cask docker

  find ~/ -name "Docker.app"
  $SUDO mv ~/Applications/Docker.app /Applications/
  open -a /Applications/Docker.app

  # Find Docker.app path
  local docker_app="/Applications/Docker.app"
  [ -d "$HOME/Applications/Docker.app" ] && docker_app="$HOME/Applications/Docker.app"

  if [ ! -d "$docker_app" ]; then
    die "Docker.app not found. Please check your installation."
  fi

  # Start Docker Desktop
  open -a "$docker_app"

  # Wait for Docker to be ready (max 60 sec)
  for i in {1..20}; do
    if docker system info &> /dev/null; then
      success "Docker is ready!"
      return
    fi
    sleep 3
  done

  die "Docker did not start in time. Please check Docker Desktop manually."
}


# Run installer based on OS
case $OS in
  ubuntu|debian)
    install_docker_ubuntu_debian ;;
  centos|rhel|fedora)
    install_docker_centos_rhel ;;
  macos)
    install_docker_macos ;;
  *)
    die "Unsupported OS: $OS. Supported: Ubuntu, Debian, CentOS/RHEL, Fedora, macOS"
    ;;
esac

# Verify Docker installation for Linux platforms
verify_linux_installation() {
  echo "Verifying Docker Installation"

  if command -v docker &> /dev/null; then
    success "Docker has been successfully installed!"
    docker --version
    docker compose version

    info "Testing Docker by running hello-world image..."
    docker run --rm hello-world

    success "Docker installation verified successfully!"
    note "You can now use Docker commands."
  else
    die "Docker installation failed. Please check the above logs."
  fi
}

# Provide final instructions based on platform
case $OS in
  ubuntu|debian|centos|rhel|fedora)
    verify_linux_installation
    ;;
  macos)
    echo "Verify Docker Installation (macOS)"
    info "1. Open Docker Desktop from Applications folder."
    info "2. After it starts, open Terminal and run: docker --version"
    info "3. Test with: docker run --rm hello-world"
    ;;
esac
