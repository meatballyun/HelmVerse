#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  cat <<'EOF'
Usage: hv cleanup

'hv cleanup' is retired. Use 'hv undeploy' or 'hv cluster down'.
EOF
  exit 0
fi

cat <<'EOF'
'hv cleanup' has been retired because it previously uninstalled Docker,
kubectl, kind, and Helm from the entire host.

Use an explicit command instead:
  hv undeploy <project>       Remove one Helm release
  hv cluster down            Remove the HelmVerse kind cluster

Host-tool uninstallers remain under scripts/ for deliberate manual use.
EOF

exit 2
