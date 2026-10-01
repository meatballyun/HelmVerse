#!/bin/bash
# ./scripts/docker/remove.sh

# Load container-manager scripts
source "./utils/container-manager.sh"

local compose_service=$1

stop_containers $compose_service
