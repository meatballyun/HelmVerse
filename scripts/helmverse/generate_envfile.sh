#!/usr/bin/env bash
# ./script/helmverse/generate_envfile.sh
#
# Purpose:
#   Generate a .env file based on config.json dependency versions.
#   Reads version numbers and outputs standard .env variables.
#
# Usage:
#   ./script/generate_env.sh [output_file]
#   Example: ./script/generate_env.sh .env.local

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

# Load utility scripts for logging and environment
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/env.sh"

CONFIG_FILE="$ROOT_DIR/config.json"
OUTPUT_FILE="${1:-$ROOT_DIR/.env}"

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Backup existing .env if exists
if [ -f "$OUTPUT_FILE" ]; then
  cp "$OUTPUT_FILE" "$OUTPUT_FILE.bak"
  echo "Backup created: $OUTPUT_FILE.bak"
fi

echo "# Auto-generated .env" > "$OUTPUT_FILE"

sed -n '/"dependencies": {/,/}/p' "$CONFIG_FILE" | grep -E '"[^"]+": "[^"]+"' | while read -r line; do
  clean_line=$(echo "$line" | tr -d ',' | xargs)
  key=$(echo "$clean_line" | cut -d':' -f1 | tr -d '"' | tr '[:lower:]-' '[:upper:]_' | xargs)
  value=$(echo "$clean_line" | cut -d':' -f2 | tr -d '"' | sed 's/\^//g' | xargs)
  echo "${key}_VERSION=$value" >> "$OUTPUT_FILE"
done

success " .env file generated at $OUTPUT_FILE"
