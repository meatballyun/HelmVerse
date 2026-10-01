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

# Parse command line arguments for namespace flag
ARGS=("$@")
for i in "${!ARGS[@]}"; do
  if [[ "${ARGS[$i]}" == "-n" ]] || [[ "${ARGS[$i]}" == "--namespace" ]]; then
    if [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
      NAMESPACE_FROM_FLAG="${ARGS[$((i + 1))]}"
    fi
    break
  fi
done

# Load NAMESPACE from .env file if it exists
if [ -f "$ENV_FILE" ]; then
  NAMESPACE_FROM_ENV=$(grep -v '^#' "$ENV_FILE" | grep '^NAMESPACE=' | cut -d '=' -f2 | xargs || echo "")
fi

# Apply priority logic
if [ -n "$NAMESPACE_FROM_FLAG" ]; then
  NAMESPACE="$NAMESPACE_FROM_FLAG"
elif [ -n "$NAMESPACE_FROM_ENV" ]; then
  NAMESPACE="$NAMESPACE_FROM_ENV"
elif [ -n "${NAMESPACE:-}" ]; then
  NAMESPACE="$NAMESPACE"
else
  NAMESPACE="default"
fi

SCRIPT_DIR="$(dirname "$0")"
POD=$("$SCRIPT_DIR/find_pod.sh" "$@")

echo "Showing logs for pod: $POD in namespace $NAMESPACE ..."
kubectl logs -f "$POD" -n "$NAMESPACE"
