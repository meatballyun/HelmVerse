#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv undeploy <project> [options]

Options:
  -p, --project NAME  Compatibility form of the project argument
  -y, --yes           Skip confirmation
  --keep-history      Retain Helm release history
  --purge-namespace   Also delete the namespace after uninstalling the release
  --timeout DURATION  Helm timeout (default: 5m)
  --dry-run           Print the action without changing the cluster

The default removes only the Helm release. Namespace deletion must be requested
explicitly because it also removes PVCs, Secrets, and non-Helm resources.
EOF
}

PROJECT=""
ASSUME_YES=false
KEEP_HISTORY=false
PURGE_NAMESPACE=false
DRY_RUN=false
TIMEOUT="5m"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT="${2:-}"; shift 2 ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    --keep-history) KEEP_HISTORY=true; shift ;;
    --purge-namespace) PURGE_NAMESPACE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)
      [[ -z "$PROJECT" ]] || die "Only one project may be specified"
      PROJECT="$1"
      shift
      ;;
  esac
done

[[ -n "$PROJECT" ]] || PROJECT="$(hv_default_project || true)"
[[ -n "$PROJECT" ]] || die "Project is required"
hv_validate_project_name "$PROJECT"
hv_require_command helm

if ! helm status "$PROJECT" --namespace "$PROJECT" >/dev/null 2>&1; then
  die "Helm release '$PROJECT' does not exist in namespace '$PROJECT'."
fi

printf 'Release:   %s\nNamespace: %s\n' "$PROJECT" "$PROJECT"
if [[ "$PURGE_NAMESPACE" == true ]]; then
  warn "The namespace and all remaining resources will also be deleted."
fi

if [[ "$DRY_RUN" == true ]]; then
  success "Dry run only. No resources were changed."
  exit 0
fi

if [[ "$ASSUME_YES" != true ]] && ! hv_confirm "Uninstall Helm release '$PROJECT'?"; then
  note "Cancelled."
  exit 0
fi

ARGS=(uninstall "$PROJECT" --namespace "$PROJECT" --wait --timeout "$TIMEOUT")
[[ "$KEEP_HISTORY" == true ]] && ARGS+=(--keep-history)
helm "${ARGS[@]}"
success "Release '$PROJECT' was uninstalled."

if [[ "$PURGE_NAMESPACE" == true ]]; then
  REMAINING_RELEASES="$(helm list --namespace "$PROJECT" --short 2>/dev/null || true)"
  [[ -z "$REMAINING_RELEASES" ]] || die "Namespace still contains Helm releases; refusing to delete it."
  hv_kubectl delete namespace "$PROJECT" --ignore-not-found=true
  success "Namespace '$PROJECT' was deleted."
fi
