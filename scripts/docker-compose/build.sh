#!/bin/bash
# ./docker/build.sh
#
# This script automates the process of:
# 1. Detecting the project root
# 2. Initializing GitOps setup (selecting project + cloning repository if needed)
# 3. Loading project-specific environment variables
# 4. Building the corresponding Docker containers using docker-compose
#
# This script assumes:
# - It's run inside a Git repository
# - The ./scripts/gitops/init_gitops.sh sets environment variables like GIT_REPO_NAME, GIT_REPO_URL, etc.
# - Project-specific env is stored in projects/<PROJECT_NAME>/project.env

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

# Initialize GitOps setup
# This script lets user select a project folder and clones the repository if necessary.
source "$ROOT_DIR/scripts/gitops/init_gitops.sh"

# Load container management utility functions (build/start/stop/remove)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/container-manager.sh"

# Load project-specific environment variables
PROJECTS_DIR="$ROOT_DIR/projects"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

if [ ! -f "${PROJECT_DIR}/project.env" ]; then
  echo "[ERROR] Missing ${PROJECT_DIR}/project.env file. Please ensure the project is initialized properly." >&2
  exit 1
fi

# Source the project environment file (loads GIT_REPO_NAME, COMPOSE_SERVICES, etc.)
load_env "${PROJECT_DIR}/project.env"

# Ask user to specify docker-compose file (optional)
read -p "$(echo -e "${BLUE}Please enter the docker compose file:${COLOR_RESET} (Default: docker.compose) ")" docker_compose
DOCKER_COMPOSE_FILE="${docker_compose:-docker.compose}"  # Use default if user input is empty

# Build containers
# Expects:
# - COMPOSE_SERVICES to be defined in project.env (list of services to build)
# - docker_compose directory exists in cloned repo
build_containers "${PROJECT_DIR}/${GIT_REPO_NAME}/${DOCKER_COMPOSE_FILE}" "${COMPOSE_SERVICES}"
