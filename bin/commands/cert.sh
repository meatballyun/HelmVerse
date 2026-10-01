#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage:
  hv cert install
  hv cert setup --email <address> [--staging]
  hv cert create-issuer --email <address> [--name <issuer>] [--staging]
  hv cert status [namespace]
  hv cert logs [controller|webhook|cainjector]

Application Certificate and Ingress resources are intentionally managed by
each project's Helm chart. The former create-cert/create-ingress/create-full
commands are retired to avoid duplicate Certificate resources and TLS secrets.
EOF
}

cmd_install() {
  if hv_kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1; then
    success "cert-manager is already installed."
    return 0
  fi
  "$HV_ROOT/scripts/kubectl/cert/install-cert-manager.sh"
}

cmd_create_issuer() {
  local email=""
  local issuer="letsencrypt-prod"
  local server="https://acme-v02.api.letsencrypt.org/directory"
  local staging=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --email) email="${2:-}"; shift 2 ;;
      --name|--issuer-name) issuer="${2:-}"; shift 2 ;;
      --staging) staging=true; shift ;;
      -h|--help) usage; return 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$email" ]] || die "--email is required"
  if [[ "$staging" == true ]]; then
    issuer="letsencrypt-staging"
    server="https://acme-staging-v02.api.letsencrypt.org/directory"
  fi

  if hv_kubectl get clusterissuer "$issuer" >/dev/null 2>&1; then
    success "ClusterIssuer '$issuer' already exists."
    return 0
  fi

  "$HV_ROOT/scripts/kubectl/cert/create-cert.sh" create-issuer \
    --email "$email" \
    --issuer-name "$issuer" \
    --server "$server" \
    --ingress-class nginx
}

cmd_setup() {
  local args=("$@")
  cmd_install
  cmd_create_issuer "${args[@]}"
}

cmd_status() {
  local namespace="${1:-}"
  headline "cert-manager"
  hv_kubectl get deployment,pod -n cert-manager 2>/dev/null || note "cert-manager is not installed"
  headline "ClusterIssuers"
  hv_kubectl get clusterissuer 2>/dev/null || note "No ClusterIssuer found"
  headline "Certificates"
  if [[ -n "$namespace" ]]; then
    hv_validate_project_name "$namespace"
    hv_kubectl get certificate,certificaterequest -n "$namespace" 2>/dev/null || note "No certificates found in $namespace"
  else
    hv_kubectl get certificate,certificaterequest -A 2>/dev/null || note "No certificates found"
  fi
}

cmd_logs() {
  local component="${1:-controller}"
  case "$component" in
    controller|c)
      hv_kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --tail=100
      ;;
    webhook|w)
      hv_kubectl logs -n cert-manager -l app.kubernetes.io/name=webhook --tail=100
      ;;
    cainjector|ci)
      hv_kubectl logs -n cert-manager -l app.kubernetes.io/name=cainjector --tail=100
      ;;
    *) die "Unknown component: $component" ;;
  esac
}

SUBCOMMAND="${1:-status}"
[[ $# -eq 0 ]] || shift

case "$SUBCOMMAND" in
  install|cert-manager) cmd_install ;;
  setup|init) cmd_setup "$@" ;;
  create-issuer|issuer) cmd_create_issuer "$@" ;;
  status|check|check-cert) cmd_status "$@" ;;
  logs) cmd_logs "$@" ;;
  create-cert|create-ingress|create-full)
    die "'$SUBCOMMAND' was retired. Declare Ingress and Certificate resources in the project Helm chart."
    ;;
  help|-h|--help) usage ;;
  *) die "Unknown cert command: $SUBCOMMAND" ;;
esac
