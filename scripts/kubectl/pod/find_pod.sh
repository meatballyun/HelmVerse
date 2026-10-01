#!/bin/bash
set -euo pipefail

# Determine NAMESPACE with priority:
# 1. Command flag -n or --namespace
# 2. .env file NAMESPACE
# 3. Environment variable NAMESPACE
# 4. Default "default"

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ENV_FILE="$ROOT_DIR/.env"
NAMESPACE_FROM_ENV=""
NAMESPACE_FROM_FLAG=""
KEYWORD=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      if [[ $# -lt 2 ]]; then
        echo "Error: -n flag requires a namespace" >&2
        exit 1
      fi
      NAMESPACE_FROM_FLAG="$2"
      shift 2
      ;;
    *)
      if [ -z "$KEYWORD" ]; then
        KEYWORD="$1"
      fi
      shift
      ;;
  esac
done

# Load NAMESPACE from .env file if it exists
if [ -f "$ENV_FILE" ]; then
  NAMESPACE_FROM_ENV=$(grep -v '^#' "$ENV_FILE" | grep '^NAMESPACE=' | cut -d '=' -f2 | xargs || echo "")
fi

# Apply priority logic
if [ -n "$NAMESPACE_FROM_FLAG" ]; then
  # Priority 1: Command flag
  NAMESPACE="$NAMESPACE_FROM_FLAG"
elif [ -n "$NAMESPACE_FROM_ENV" ]; then
  # Priority 2: .env file
  NAMESPACE="$NAMESPACE_FROM_ENV"
elif [ -n "${NAMESPACE:-}" ]; then
  # Priority 3: Environment variable
  NAMESPACE="$NAMESPACE"
else
  # Priority 4: Default
  NAMESPACE="default"
fi

NAMESPACE="$(echo "$NAMESPACE" | xargs)"   # 去除前後空白

if [ -z "$KEYWORD" ]; then
  echo "Usage: $0 [-n namespace] <keyword>" >&2
  exit 1
fi

MATCHED=$(kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.name" | grep "$KEYWORD" || true)
COUNT=$(echo "$MATCHED" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "No pod found matching: $KEYWORD" >&2
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "Multiple pods found:" >&2
  echo "$MATCHED" >&2
  exit 1
fi

echo "$MATCHED"
