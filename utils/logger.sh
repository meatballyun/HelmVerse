#!/bin/bash
# ./utils/logger.sh
# Utility functions for colored logging in shell scripts

# Define color codes for different log levels
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
MAGENTA='\033[1;35m'
COLOR_RESET="\033[0m"

# Log an info message (blue)
info() { echo -e "${BLUE}[INFO]${COLOR_RESET} $*"; }

# Log a success message (green)
success() { echo -e "${GREEN}[SUCCESS]${COLOR_RESET} $*"; }

# Log a warning message (yellow)
warn() { echo -e "${YELLOW}[WARN]${COLOR_RESET} $*"; }

# Log an error message (red)
error() { echo -e "${RED}[ERROR]${COLOR_RESET} $*"; }

# Log a note message (cyan) - for minor notices or additional info
note() { echo -e "${CYAN}[NOTE]${COLOR_RESET} $*"; }

# Print a big headline separator (blue) - good for marking major steps
headline() { echo -e "\n${BLUE}========== $* ==========${COLOR_RESET}\n"; }

# Log an error and exit the script
die() { error "$*"; exit 1; }
