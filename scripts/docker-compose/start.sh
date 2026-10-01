#!/bin/bash
# ./scripts/docker/restart.sh

# Load container-manager scripts
source "./utils/container-manager.sh"

local compose_service=$1

start_containers $compose_service
