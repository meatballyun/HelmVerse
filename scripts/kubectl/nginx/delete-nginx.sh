#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../utils/hv_common.sh
source "$SCRIPT_DIR/../../../utils/hv_common.sh"
kubectl() { hv_kubectl "$@"; }

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Delete Kubernetes resources in reverse order of creation to respect dependencies.

# Change to the directory where the YAML files are located
cd "$(dirname "$0")"

echo -e "${RED}Deleting NGINX Ingress Controller...${NC}"

# IngressClass and ValidatingWebhookConfiguration first
echo -e "${YELLOW}[1/4] Deleting ingress class and webhook configuration...${NC}"
kubectl delete -f validatingwebhookconfiguration/validatingwebhookconfiguration-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f ingressclass/ingressclass-nginx.yaml --ignore-not-found=true

# Jobs
echo -e "${YELLOW}[2/4] Deleting jobs...${NC}"
kubectl delete -f job/job-ingress-nginx-admission-patch.yaml --ignore-not-found=true
kubectl delete -f job/job-ingress-nginx-admission-create.yaml --ignore-not-found=true

# Deployment, Services, ConfigMap
echo -e "${YELLOW}[3/4] Deleting deployment, services, and configmap...${NC}"
kubectl delete -f deployment/deployment-ingress-nginx-controller.yaml --ignore-not-found=true
kubectl delete -f service/service-ingress-nginx-controller-admission.yaml --ignore-not-found=true
kubectl delete -f service/service-ingress-nginx-controller.yaml --ignore-not-found=true
kubectl delete -f configmap/configmap-ingress-nginx-controller.yaml --ignore-not-found=true

# ClusterRoleBindings, RoleBindings, ClusterRoles, Roles, ServiceAccounts
echo -e "${YELLOW}[4/4] Deleting roles, bindings, service accounts, and namespace...${NC}"
kubectl delete -f clusterrolebinding/clusterrolebinding-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f clusterrolebinding/clusterrolebinding-ingress-nginx.yaml --ignore-not-found=true
kubectl delete -f rolebinding/rolebinding-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f rolebinding/rolebinding-ingress-nginx.yaml --ignore-not-found=true
kubectl delete -f clusterrole/clusterrole-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f clusterrole/clusterrole-ingress-nginx.yaml --ignore-not-found=true
kubectl delete -f role/role-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f role/role-ingress-nginx.yaml --ignore-not-found=true
kubectl delete -f serviceaccount/serviceaccount-ingress-nginx-admission.yaml --ignore-not-found=true
kubectl delete -f serviceaccount/serviceaccount-ingress-nginx.yaml --ignore-not-found=true

# Namespace last
kubectl delete -f namespace/namespace.yaml --ignore-not-found=true

echo -e "${GREEN}✅ All NGINX Ingress Controller resources deleted.${NC}"
