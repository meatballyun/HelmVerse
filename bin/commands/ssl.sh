#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/hv_common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  cat <<'EOF'
Usage: hv ssl <command> [options]

Deprecated alias for 'hv cert'. Existing subcommands are forwarded.
EOF
  exit 0
fi

hv_warn_deprecated "hv ssl" "Use 'hv cert' instead."
SUBCOMMAND="${1:-status}"
[[ $# -eq 0 ]] || shift
case "$SUBCOMMAND" in
  cert-manager|cm) SUBCOMMAND=install ;;
  issuer|cluster-issuer|ci) SUBCOMMAND=create-issuer ;;
  check-cert) SUBCOMMAND=status ;;
esac
exec "$SCRIPT_DIR/cert.sh" "$SUBCOMMAND" "$@"
