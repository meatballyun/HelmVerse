#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv status [project] [--no-http]

Without a project, lists all Helm releases. With a project, shows the release,
pods, services, ingress, certificates, and public HTTPS response.
EOF
}

PROJECT=""
CHECK_HTTP=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-http) CHECK_HTTP=false; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)
      [[ -z "$PROJECT" ]] || die "Only one project may be specified"
      PROJECT="$1"
      shift
      ;;
  esac
done

hv_require_command helm

if [[ -z "$PROJECT" ]]; then
  PROJECT="$(hv_default_project || true)"
fi

if [[ -z "$PROJECT" ]]; then
  headline "Helm releases"
  helm list --all-namespaces
  exit 0
fi

hv_validate_project_name "$PROJECT"

headline "Release: $PROJECT"
if ! helm status "$PROJECT" --namespace "$PROJECT" --show-desc; then
  error "Helm release '$PROJECT' is not deployed in namespace '$PROJECT'."
  exit 1
fi

headline "Workloads"
hv_kubectl get deployments,statefulsets,pods -n "$PROJECT" -o wide 2>/dev/null || note "No workloads found"

headline "Services"
hv_kubectl get services -n "$PROJECT" -o wide 2>/dev/null || note "No services found"

headline "Ingress"
hv_kubectl get ingress -n "$PROJECT" -o wide 2>/dev/null || note "No ingress found"

headline "Certificates"
hv_kubectl get certificate,certificaterequest -n "$PROJECT" 2>/dev/null || note "No cert-manager resources found"

if [[ "$CHECK_HTTP" == true ]] && command -v curl >/dev/null 2>&1; then
  HOSTS="$(hv_kubectl get ingress -n "$PROJECT" -o jsonpath='{range .items[*].spec.rules[*]}{.host}{"\n"}{end}' 2>/dev/null | sort -u || true)"
  if [[ -n "$HOSTS" ]]; then
    headline "HTTPS"
    while IFS= read -r host; do
      [[ -n "$host" ]] || continue
      code="$(curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "https://$host" 2>/dev/null || true)"
      printf '%-48s %s\n' "https://$host" "${code:-unreachable}"
    done <<< "$HOSTS"
  fi
fi
