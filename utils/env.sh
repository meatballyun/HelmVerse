#!/bin/bash
# ./utils/env.sh
#
# Purpose:
#   Shell utilities for managing environment variables in projects.
#   Provides functions to load, validate, export, and require .env variables.
#   Useful for local scripts, CI/CD pipelines, and deployment automation.
#
# Usage examples:
#   load_env [--silent] <env_file1> [env_file2 ...]
#   require_env <VAR1> [VAR2 ...]
#   print_env <VAR1> [VAR2 ...]
#   export_env_to_file <output_file> [VAR1 VAR2 ...]
#   validate_env_file <env_file>
#
# Functions provided:
#   - load_env            Load environment variables from one or more .env files (auto-exported)
#   - require_env         Ensure required environment variables are defined (script will exit if missing)
#   - print_env           Print selected environment variables (useful for debugging)
#   - export_env_to_file  Export selected environment variables into a .env format file
#   - validate_env_file   Validate .env file syntax (checks KEY=VALUE pairs)
#
# Arguments:
#   load_env:
#     --silent         Suppress warnings if .env file not found
#     <env_file>       Path(s) to .env file(s) to load
#
#   export_env_to_file:
#     <output_file>    File to write exported env variables
#     [VAR...]         List of env variable names to export
#
#   validate_env_file:
#     <env_file>       Path to .env file to validate

# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Load environment variables from one or more .env files
load_env() {
  local silent=0

  # Detect if "--silent" flag is passed
  if [ "$1" == "--silent" ]; then
    silent=1
    shift
  fi

  # Accept multiple files
  local env_file
  for env_file in "$@"; do
    if [ -z "$env_file" ]; then
      continue  # Skip empty arguments
    fi

    if [ -f "$env_file" ]; then
      [[ "$silent" -eq 0 ]] && info "Loading environment from $env_file"
      set -a  # Auto-export variables
      source "$env_file"
      set +a
    else
      [[ "$silent" -eq 0 ]] && warn "No env file found at $env_file"
    fi
  done
}

# Require certain environment variables to be defined (exit if missing)
require_env() {
  local missing=0
  for var in "$@"; do
    if [ -z "${!var}" ]; then
      error "Required environment variable '$var' is not set"
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

# Print selected environment variables (for debugging)
print_env() {
  for var in "$@"; do
    echo "$var=${!var}"
  done
}

# Export selected env variables to a .env file
export_env_to_file() {
  local output_file="$1"
  shift

  if [ -z "$output_file" ]; then
    error "Output file not specified."
    exit 1
  fi

  info "Exporting environment variables to $output_file"

  # Backup existing file if exists
  if [ -f "$output_file" ]; then
    cp "$output_file" "$output_file.bak"
    info "Backup created: $output_file.bak"
  fi

  : > "$output_file"  # Truncate output file

  for var in "$@"; do
    if [ -z "${!var+x}" ]; then
      warn "Variable '$var' is not set. Skipping."
      continue
    fi
    echo "$var=${!var}" >> "$output_file"
  done

  info "Export completed: $output_file"
}

# Export selected env variables to a origin .env file
export_env_to_file_append() {
  local output_file="$1"
  shift

  if [ -z "$output_file" ]; then
    error "Output file not specified."
    exit 1
  fi

  info "Appending environment variables to $output_file"

  # Backup existing file if exists
  if [ -f "$output_file" ]; then
    cp "$output_file" "$output_file.bak"
    info "Backup created: $output_file.bak"
  fi

  for var in "$@"; do
    if [ -z "${!var+x}" ]; then
      warn "Variable '$var' is not set. Skipping."
      continue
    fi
    # Remove origin variable（Both on macOS and Linux）
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "/^$var=/d" "$output_file"  # macOS
    else
      sed -i "/^$var=/d" "$output_file"    # Linux
    fi
    echo "$var=${!var}" >> "$output_file"
  done
  rm -f "$output_file.bak"

  info "Append completed: $output_file"
}

# Validate .env file format
validate_env_file() {
  local env_file="$1"
  if [ ! -f "$env_file" ]; then
    error "Env file not found: $env_file"
    exit 1
  fi

  info "Validating env file: $env_file"
  local invalid_lines=0
  local line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Validate KEY=VALUE format (alphanumeric keys + _)
    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      error "Invalid line $line_num: $line"
      invalid_lines=$((invalid_lines + 1))
    fi
  done < "$env_file"

  if [ "$invalid_lines" -ne 0 ]; then
    error "Validation failed: $invalid_lines invalid lines found."
    exit 1
  fi

  info "Validation passed: $env_file"
}
