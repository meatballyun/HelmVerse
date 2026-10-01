#!/bin/bash
# ./scripts/docker/utils/container-manager.sh
#
# Purpose:
#   Provides utility functions for managing Docker containers and services in a project environment.
#   Includes operations for checking Docker status, defining container names, and managing container lifecycles (start, stop, remove).
#   Useful for automating Docker-related tasks and simplifying container management in a development or production environment.
#
# Usage:
#   - check_docker_running               Check if Docker is running and accessible.
#   - define_container_names <title> <prop> <compose_service> [print_container]   Define container names based on project title, environment, and services.
#   - container_exists <container_name>   Check if a specific container exists.
#   - container_running <container_name>  Check if a specific container is running.
#   - build_containers <compose_file> <service_name>   Build and start containers using Docker Compose.
#   - start_container <container_name>    Start a specific Docker container.
#   - stop_container <container_name>     Stop a specific Docker container.
#   - remove_container <container_name>   Remove a specific Docker container.
#   - start_containers <compose_service>  Start all containers defined by the project services.
#   - stop_containers <compose_service>   Stop all containers defined by the project services.
#   - remove_containers <compose_service> Remove all containers defined by the project services.
#
# Arguments:
#   <title>            (Required) Project title used to define container names.
#   <prop>             (Required) Environment property (e.g., 'development', 'production') for the project.
#   <compose_service>  (Required) List of Docker Compose service names to define container names for.
#   [print_container]  (Optional) If set to "true", container names will be printed after definition. Defaults to "false".
#   <container_name>   (Required) Name of the container to manage (start, stop, remove).
#   <compose_file>     (Required) Path to the Docker Compose file.
#   <service_name>     (Optional) Name of a specific service to build/start. If omitted, all services will be built/started.
#
# Example:
#   - check_docker_running
#     This will check if Docker is running and accessible. If not, it will show an error.
#
#   - define_container_names my-project development "frontend backend api" true
#     This will define container names for the 'frontend', 'backend', and 'api' services based on the project title "my-project" and environment "development".
#     The container names will be printed since the 'print_container' option is set to "true".
#
#   - build_containers docker-compose.yml frontend
#     This will build and start the 'frontend' service from the specified Docker Compose file.
#
#   - start_containers "frontend backend"
#     This will start all containers defined by the "frontend" and "backend" services.
#
#   - stop_containers "frontend backend"
#     This will stop all containers defined by the "frontend" and "backend" services.
#
#   - remove_containers "frontend backend"
#     This will remove all containers defined by the "frontend" and "backend" services.
#
# Dependencies:
#   - docker: Command-line tool for managing Docker containers.
#   - docker-compose: Tool for defining and running multi-container Docker applications.
#   - logger.sh: A separate script for logging output (info, warn, error).
#
# Ensure Docker is installed and running before using these functions.
# Customize this script for the specific services and container names used in your project environment.

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

# Load utility scripts providing reusable functions
source "$ROOT_DIR/utils/logger.sh"

# Check if Docker is running
check_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    error "Docker is not running or not accessible. Please start Docker and try again."
    exit 1
  fi
  info "Docker is running."
}

# Define container names based on project title, environment property, and optional print_container flag
define_container_names() {
  local title="$1"
  local prop="$2"
  local compose_service="$3"
  local print_container="${4:-false}"  # Default to false if print_container is not passed

  # Validate required parameters
  if [ -z "$title" ] || [ -z "$prop" ]; then
    error "❌ Missing required parameters: title and/or prop."
    exit 1
  fi

  # Initialize associative array to store container names
  declare -g -A CONTAINERS

  # Generate container names if services are provided
  if [ -n "$compose_service" ]; then
    info "🔧 Defining container names from services: $compose_service"

    # Iterate through each service and create container names
    for service in $compose_service; do
      CONTAINERS[$service]="${title}-${service}-${prop}"
    done
  else
    info "⚠️ No compose_service specified. Skipping container name generation."
  fi

  info "✅ Container naming convention applied for project: \"$title\" (env: \"$prop\")"

  # Optionally print container names if print_container is true
  if [ "$print_container" = true ]; then
    info "📦 Generated container names:"
    for container in "${!CONTAINERS[@]}"; do
      info "   • $container → ${CONTAINERS[$container]}"
    done
  else
    info "📦 Container names generation complete. Use print_container=true to display them."
  fi
}

# Check if container exists
container_exists() {
  local container_name="$1"
  docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"
  return $?
}

# Check if container is running
container_running() {
  local container_name="$1"
  docker ps --format "{{.Names}}" | grep -q "^${container_name}$"
  return $?
}

# Docker Compose Build
build_containers() {
  local compose_file="$1"
  local service_name="$2"

  if [ -z "$compose_file" ]; then
  error "compose_file is not defined"
  exit 1
  fi

  echo "🚀 Starting with compose file: $compose_file"

   # Check if compose file exists
  if [ ! -f "$compose_file" ]; then
    error "Compose file not found: $compose_file"
    exit 1
  fi

  # If no specific service is provided, build all
  if [ -z "$service_name" ]; then
    echo "🔄 No service specified, starting ALL services..."
    docker-compose -f "$compose_file" up -d --build
    local status=$?
    if [ $status -ne 0 ]; then
      warn "Failed to build and start all services."
      return $status
    fi
    success "All services have been started successfully."
  else
    echo "🚀 Building and starting service: $service_name"
    docker-compose -f "$compose_file" up -d --build "$service_name"
    local status=$?
    if [ $status -ne 0 ]; then
      warn "Failed to build and start service: $service_name."
      return $status
    fi
    success "Service $service_name has been started successfully."
  fi
}

# Docker start
start_container() {
  local container_name="$1"

  if container_exists "$container_name"; then
    if container_running "$container_name"; then
      info "Container $container_name already running"
    else
      info "🚀 Starting container: $container_name"
      docker start "$container_name" || warn "Failed to start container $container_name."
    fi
  else
    warn "Container $container_name does not exist."
  fi
}

# Docker stop
stop_container() {
  local container_name="$1"

  if container_exists "$container_name"; then
    if container_running "$container_name"; then
      info "🛑 Stopping container: $container_name"
      docker stop "$container_name" || warn "Container $container_name may not be running."
    else
      info "Container $container_name already stop."
    fi
  else
    warn "Container $container_name does not exist."
  fi
}

# Docker remove
remove_container() {
  local container_name="$1"

  if container_exists "$container_name"; then
    if container_running "$container_name"; then
      stop_container "$container_name"
    fi

    info "🗑️  Removing container: $container_name"
    docker rm "$container_name" || warn "Container $container_name may not exist."
  else
    warn "Container $container_name does not exist."
  fi
}

# Start containers
start_containers() {
  local compose_service="$1"

  if [ -z "$compose_service" ]; then
    warn "No service names provided. Please specify at least one service."
    return 1
  fi

  define_container_names

  echo -e "\n====== [Starting Containers] ======\n"
  for container in "${!CONTAINERS[@]}"; do
    start_container "${CONTAINERS[$container]}"
  done
  success "All containers started.\n"
}

# Stop containers
stop_containers() {
  local compose_service="$1"

  if [ -z "$compose_service" ]; then
    warn "No service names provided. Please specify at least one service."
    return 1
  fi

  define_container_names

  echo -e "\n====== [Stopping Containers] ======\n"
  for container in "${!CONTAINERS[@]}"; do
    stop_container "${CONTAINERS[$container]}"
  done
  success "All containers stopped.\n"
}

# Remove containers
remove_containers() {
  local compose_service="$1"

  if [ -z "$compose_service" ]; then
    warn "No service names provided. Please specify at least one service."
    return 1
  fi

  define_container_names

  echo -e "\n====== [Removing Containers] ======\n"
  for container in "${!CONTAINERS[@]}"; do
    remove_container "${CONTAINERS[$container]}"
  done
  success "All containers removed.\n"
}
