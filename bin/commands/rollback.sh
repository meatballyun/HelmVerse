#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv rollback <project> [revision] [--timeout <duration>] [--dry-run]

Revision 0 (the default) selects the previous release revision.
EOF
}

PROJECT=""
REVISION="0"
TIMEOUT="5m"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *)
      if [[ -z "$PROJECT" ]]; then PROJECT="$1"
      elif [[ "$REVISION" == "0" ]]; then REVISION="$1"
      else die "Too many arguments"
      fi
      shift
      ;;
  esac
done

[[ -n "$PROJECT" ]] || die "Project is required"
hv_validate_project_name "$PROJECT"
[[ "$REVISION" =~ ^[0-9]+$ ]] || die "Revision must be numeric"
hv_require_command helm

helm history "$PROJECT" --namespace "$PROJECT"
ARGS=(rollback "$PROJECT" "$REVISION" --namespace "$PROJECT" --wait --cleanup-on-fail --timeout "$TIMEOUT")
[[ "$DRY_RUN" == true ]] && ARGS+=(--dry-run)
helm "${ARGS[@]}"

if [[ "$DRY_RUN" == true ]]; then
  success "Rollback dry run completed."
else
  success "Rollback completed."
fi
