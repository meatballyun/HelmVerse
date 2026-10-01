#!/bin/bash
set -e

# Detect project root and load logger
ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi
source "$ROOT_DIR/utils/logger.sh"
source "$ROOT_DIR/utils/hv_common.sh"

# Keep the manifest sequence readable while supporting hosts where kubectl is
# available only inside the kind control-plane container.
kubectl() { hv_kubectl "$@"; }

# Change to the directory where the YAML files are located
cd "$(dirname "$0")"

# Apply Kubernetes resources in a specific order to ensure dependencies are met.
info "Deploying NGINX Ingress Controller..."

# Namespace, ServiceAccounts, Roles, and RoleBindings first
info "[1/4] Creating namespace, service accounts, roles, and bindings..."
kubectl apply -f namespace/namespace.yaml
kubectl apply -f serviceaccount/serviceaccount-ingress-nginx.yaml
kubectl apply -f serviceaccount/serviceaccount-ingress-nginx-admission.yaml
kubectl apply -f role/role-ingress-nginx.yaml
kubectl apply -f role/role-ingress-nginx-admission.yaml
kubectl apply -f clusterrole/clusterrole-ingress-nginx.yaml
kubectl apply -f clusterrole/clusterrole-ingress-nginx-admission.yaml
kubectl apply -f rolebinding/rolebinding-ingress-nginx.yaml
kubectl apply -f rolebinding/rolebinding-ingress-nginx-admission.yaml
kubectl apply -f clusterrolebinding/clusterrolebinding-ingress-nginx.yaml
kubectl apply -f clusterrolebinding/clusterrolebinding-ingress-nginx-admission.yaml

# ConfigMap, Services, Deployment
info "[2/4] Creating configmap, services, and deployment..."
kubectl apply -f configmap/configmap-ingress-nginx-controller.yaml
kubectl apply -f service/service-ingress-nginx-controller.yaml
kubectl apply -f service/service-ingress-nginx-controller-admission.yaml
kubectl apply -f deployment/deployment-ingress-nginx-controller.yaml

# Jobs, IngressClass, ValidatingWebhookConfiguration
info "[3/4] Creating jobs, ingress class, and webhook configuration..."
kubectl apply -f job/job-ingress-nginx-admission-create.yaml
kubectl apply -f job/job-ingress-nginx-admission-patch.yaml
kubectl apply -f ingressclass/ingressclass-nginx.yaml
kubectl apply -f validatingwebhookconfiguration/validatingwebhookconfiguration-ingress-nginx-admission.yaml

# Wait for deployment to be ready
info "[4/4] Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --for=condition=Available deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s

success "All NGINX Ingress Controller resources applied successfully."
echo ""
note "To check status, run: hv nginx status"
note "To create an Ingress resource, run: hv nginx create"
