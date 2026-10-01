#!/bin/bash
set -euo pipefail

# Determine NAMESPACE_NAME with priority:
# 1. Command flag -n
# 2. .env file NAMESPACE
# 3. Environment variable NAMESPACE
# 4. Default "default"

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ENV_FILE="$ROOT_DIR/.env"
NAMESPACE_FROM_ENV=""
NAMESPACE_FROM_FLAG=""

# Parse command line arguments for -n or --namespace flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      if [[ $# -lt 2 ]]; then
        echo "Error: -n flag requires a namespace" >&2
        exit 1
      fi
      NAMESPACE_FROM_FLAG="$2"
      shift 2
      ;;
    *)
      echo "No namespace flag provided"
      shift
      ;;
  esac
done

# Load NAMESPACE from .env file if it exists
if [ -f "$ENV_FILE" ]; then
  NAMESPACE_FROM_ENV=$(grep -v '^#' "$ENV_FILE" | grep '^NAMESPACE=' | cut -d '=' -f2 | xargs || echo "")
fi

if [ -n "$NAMESPACE_FROM_FLAG" ]; then
  echo "Namespace from flag: $NAMESPACE_FROM_FLAG"
  NAMESPACE_NAME="$NAMESPACE_FROM_FLAG"
elif [ -n "$NAMESPACE_FROM_ENV" ]; then
  echo "Namespace from env: $NAMESPACE_FROM_ENV"
  NAMESPACE_NAME="$NAMESPACE_FROM_ENV"
elif [ -n "${NAMESPACE:-}" ]; then
  echo "Namespace from env var: $NAMESPACE"
  NAMESPACE_NAME="$NAMESPACE"
else
  echo "Namespace from default"
  NAMESPACE_NAME="default"
fi

echo "Listing pods in namespace: $NAMESPACE_NAME"
kubectl get pods -n "$NAMESPACE_NAME" -o wide
