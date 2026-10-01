#!/bin/bash
# ./scripts/helmverse/initialization_message.sh

# With strict mode for safer scripting
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory using Git
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

# Exit if not inside a Git repository (enforces script to be project-bound)
if [ -z "$ROOT_DIR" ]; then
   echo "[ERROR] Failed to detect project root. Make sure you're running inside a git repository." >&2
   exit 1
fi

# Version detection: fallback to manual if git describe fails
VERSION="v0.1.0"

# Load utility scripts for logging
source "$ROOT_DIR/utils/logger.sh"

echo -e "${YELLOW}";
echo "██╗  ██╗███████╗██╗     ███╗   ███╗██╗   ██╗███████╗██████╗  ▄████▄  ███████╗"
echo "██║  ██║██╔════╝██║     ████╗ ████║██║   ██║██╔════╝██╔══██╗██╝   ▀▀ ██╔════╝"
echo "███████║█████╗  ██║     ██╔████╔██║██║   ██║█████╗  ██████╔╝ ▀████▄  █████╗  "
echo "██╔══██║██╔══╝  ██║     ██║╚██╔╝██║╚██╗ ██╔╝██╔══╝  ██╔══██╗▄▄   ╚██ ██╔══╝  "
echo "██║  ██║███████╗███████╗██║ ╚═╝ ██║ ╚████╔╝ ███████╗██║  ██║ ▀████▀  ███████╗"
echo "╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝"
echo -e "${CYAN}░░░░░░░░░░░░░░░░░ © $(date +%Y) BUMIVERSE. All rights reserved. ░░░░░░░░░░░░░░░░░░░░${COLOR_RESET}"
echo ""

echo -e "${MAGENTA}Version: ${VERSION}${COLOR_RESET}"
echo ""

echo -e "${GREEN}✓ Initialization completed successfully!${COLOR_RESET}"
echo -e "${YELLOW}Type 'hev --help' for available commands${COLOR_RESET}"
echo -e "${YELLOW}Join our community: https://bumiverse.com${COLOR_RESET}"
echo -e "${YELLOW}Report issues at: https://github.com/meatballyun/HelmVerse/issues${COLOR_RESET}"
echo -e "${GREEN}✓ Next: Try running 'hv deploy' to start your journey!${COLOR_RESET}"
echo ""
