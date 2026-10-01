#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/hv_common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
  cat <<'EOF'
Usage: hv set-namespace <project>

Deprecated alias for: hv config set namespace <project>
EOF
  exit 0
fi

hv_warn_deprecated "hv set-namespace" "Use 'hv config set namespace <project>'."
exec "$SCRIPT_DIR/config.sh" set namespace "$1"
