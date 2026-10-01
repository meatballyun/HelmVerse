#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage:
  hv config show
  hv config get namespace|cluster
  hv config set namespace <project>
  hv config set cluster <name>

Only non-secret HelmVerse defaults are managed here. Project secrets do not
belong in .env or values.yaml.
EOF
}

key_for_name() {
  case "$1" in
    namespace|project) printf 'NAMESPACE\n' ;;
    cluster) printf 'KIND_DEFAULT_CLUSTER_NAME\n' ;;
    *) die "Unknown configuration name: $1" ;;
  esac
}

SUBCOMMAND="${1:-show}"
[[ $# -eq 0 ]] || shift

case "$SUBCOMMAND" in
  show)
    printf 'root=%s\n' "$HV_ROOT"
    printf 'projects=%s\n' "$HV_PROJECTS_DIR"
    printf 'namespace=%s\n' "$(hv_default_project || true)"
    printf 'cluster=%s\n' "$(hv_cluster_name)"
    ;;
  get)
    [[ $# -eq 1 ]] || die "Usage: hv config get namespace|cluster"
    KEY="$(key_for_name "$1")"
    hv_config_get "$KEY" || true
    ;;
  set)
    [[ $# -eq 2 ]] || die "Usage: hv config set namespace|cluster <value>"
    KEY="$(key_for_name "$1")"
    VALUE="$2"
    if [[ "$KEY" == "NAMESPACE" ]]; then
      hv_validate_project_name "$VALUE"
    else
      hv_validate_project_name "$VALUE"
    fi
    hv_config_set "$KEY" "$VALUE"
    success "Set $1 to '$VALUE'."
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    die "Unknown config command: $SUBCOMMAND"
    ;;
esac
