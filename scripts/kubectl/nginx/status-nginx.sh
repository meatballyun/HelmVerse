#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../utils/hv_common.sh
source "$SCRIPT_DIR/../../../utils/hv_common.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Show the status of ingress-nginx pods and services.

echo -e "${GREEN}📊 NGINX Ingress Controller Status:${NC}"
echo ""

echo -e "${YELLOW}Pods:${NC}"
hv_kubectl get pods -n ingress-nginx

echo ""
echo -e "${YELLOW}Services:${NC}"
hv_kubectl get svc -n ingress-nginx

echo ""
echo -e "${YELLOW}Deployments:${NC}"
hv_kubectl get deployment -n ingress-nginx

echo ""
echo -e "${YELLOW}Ingress Class:${NC}"
hv_kubectl get ingressclass

echo ""
echo -e "${YELLOW}All Ingress Resources:${NC}"
hv_kubectl get ingress --all-namespaces
