#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../utils/hv_common.sh
source "$SCRIPT_DIR/../../../utils/hv_common.sh"

echo "Installing Cert-Manager..."
hv_kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml

echo "⏳ Waiting for Cert-Manager to be ready..."
hv_kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=180s
hv_kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=180s
hv_kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=180s

echo "✅ Cert-Manager installed successfully."
