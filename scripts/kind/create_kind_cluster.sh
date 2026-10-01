#!/usr/bin/env bash
# ./scripts/kind/create_kind_cluster.sh
#
# Purpose:
#   Initialize a Kind cluster based on existing kind-config.yaml.
#
# Usage:
#   ./scripts/kind/create_kind_cluster.sh

# Safer scripting mode
set -euo pipefail
IFS=$'\n\t'

# Resolve from the script location so 'hv cluster up' works from any directory.
ROOT_DIR="${HV_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Load utility scripts (optional if you want colored logs)
source "$ROOT_DIR/utils/logger.sh"

# Kind config path
KIND_CONFIG_FILE="$ROOT_DIR/config/kind-config.yaml"

# Check if kind-config.yaml exists
if [ ! -f "$KIND_CONFIG_FILE" ]; then
  error "Missing $KIND_CONFIG_FILE. Please create it first." >&2
  exit 1
fi

info "🔍 Found config: $KIND_CONFIG_FILE"

# Extract cluster name from kind-config.yaml
CLUSTER_NAME=$(yq '.name' "$KIND_CONFIG_FILE" 2>/dev/null || grep '^name:' "$KIND_CONFIG_FILE" | awk '{print $2}')

if [ -z "$CLUSTER_NAME" ]; then
  error "Failed to read cluster name from config." >&2
  exit 1
fi
# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  info "⚠️  Kind cluster '$CLUSTER_NAME' already exists. Skipping creation."
else
  info "🚀 Creating Kind cluster: $CLUSTER_NAME ..."
  kind create cluster --config "$KIND_CONFIG_FILE"
fi

# Apply the node-side NAT rule idempotently on both new and existing clusters.
info "🌐 Detecting Pod Subnet from config..."
POD_SUBNET=$(grep 'podSubnet:' "$KIND_CONFIG_FILE" | awk '{print $2}' | tr -d '"' || true)
POD_SUBNET="${POD_SUBNET:-10.10.0.0/16}"
NODE_NAME="${CLUSTER_NAME}-control-plane"

info "🔧 Ensuring NAT for subnet $POD_SUBNET on node $NODE_NAME..."
docker exec "$NODE_NAME" sysctl -w net.ipv4.ip_forward=1 >/dev/null
if ! docker exec "$NODE_NAME" iptables -t nat -C POSTROUTING -s "$POD_SUBNET" ! -d "$POD_SUBNET" -j MASQUERADE 2>/dev/null; then
  docker exec "$NODE_NAME" iptables -t nat -A POSTROUTING -s "$POD_SUBNET" ! -d "$POD_SUBNET" -j MASQUERADE
fi

success "✅ Cluster '$CLUSTER_NAME' and node networking are ready."
