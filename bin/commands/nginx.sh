#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

SUBCOMMAND="${1:-status}"
[[ $# -eq 0 ]] || shift

case "$SUBCOMMAND" in
  init|install)
    hv_warn_deprecated "hv nginx" "Prefer 'hv cluster addon install ingress'."
    "$HV_ROOT/scripts/kubectl/nginx/deploy-nginx.sh"
    ;;
  status)
    "$HV_ROOT/scripts/kubectl/nginx/status-nginx.sh"
    ;;
  delete|remove|uninstall)
    hv_warn_deprecated "hv nginx" "Prefer 'hv cluster addon remove ingress'."
    "$HV_ROOT/scripts/kubectl/nginx/delete-nginx.sh"
    ;;
  help|-h|--help)
    cat <<'EOF'
Usage: hv nginx install|status|remove

Compatibility alias. Prefer 'hv cluster addon ...' for new scripts.
EOF
    ;;
  *) die "Unknown nginx command: $SUBCOMMAND" ;;
esac
