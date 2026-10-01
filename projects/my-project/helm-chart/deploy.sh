#!/usr/bin/env bash
set +x
set -euo pipefail
CHART_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HV_ROOT="${HV_ROOT:-$(cd "$CHART_ROOT/../../.." && pwd)}"
source "$HV_ROOT/utils/project_deploy.sh"
project_deploy_init "${BASH_SOURCE[0]}" 5m
project_deploy_parse_args "$@"

# This project chooses its optional encrypted values file.
if [[ -f "$SECRETS_FILE" ]]; then
  project_deploy_load_sops
elif [[ "$SECRETS_FILE_EXPLICIT" == true ]]; then
  die "Encrypted values file not found: $SECRETS_FILE"
else
  note "No encrypted values for $ENVIRONMENT; skipping SOPS."
fi

project_deploy_require_cluster
project_deploy_run
