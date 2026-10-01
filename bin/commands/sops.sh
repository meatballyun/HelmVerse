#!/usr/bin/env bash
set +x
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/hv_common.sh"
if [[ "${1:-}" == init ]]; then
  shift
  exec "$HV_ROOT/scripts/sops/install_sops.sh" "$@"
fi
hv_require_command python3
exec python3 "$HV_ROOT/utils/sops_values.py" prepare "$@"
