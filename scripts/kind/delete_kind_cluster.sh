#!/usr/bin/env bash
# ./scripts/kind/delete_kind_cluster.sh
#
# Purpose:
#   Delete Kind cluster using config from .env or default.env.
#
# Usage:
#   ./scripts/kind/delete_kind_cluster.sh

# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Detect project root directory
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"

if [ -z "$ROOT_DIR" ]; then
  echo "[ERROR] Failed to detect project root. Make sure you're inside a git repository." >&2
  exit 1
fi

# Load utility scripts
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/env.sh"

# Try to load .env or fallback to default.env
ENV_FILE="$ROOT_DIR/.env"
DEFAULT_ENV="$ROOT_DIR/default.env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
  echo "[INFO] Loaded config from .env"
elif [ -f "$DEFAULT_ENV" ]; then
  source "$DEFAULT_ENV"
  echo "[INFO] Loaded config from default.env"
else
  echo "[ERROR] No .env or default.env found. Please initialize first." >&2
  exit 1
fi

# Fallback cluster name
CLUSTER_NAME="${KIND_DEFAULT_CLUSTER_NAME:-helmverse}"

echo "⚠️  Target cluster for deletion: '$CLUSTER_NAME'"

# Confirm before deleting
read -rp "❓ Are you sure you want to delete Kind cluster '$CLUSTER_NAME'? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "🚫 Aborted. No cluster was deleted."
  exit 0
fi

# Delete the cluster
kind delete cluster --name "$CLUSTER_NAME"
success "Kind cluster '$CLUSTER_NAME' deleted successfully!"
