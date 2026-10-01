#!/bin/bash
# ./scripts/docker/restart.sh

local compose_service=$1

./stop.sh $compose_service && ./start.sh $compose_service
