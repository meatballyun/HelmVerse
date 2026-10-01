#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv logs [pod-keyword] [options]

Options:
  -f, --follow          Follow log output
  -p, --project NAME    Project/namespace (default: configured namespace)
  -c, --container NAME Select a container
  --tail NUMBER         Number of recent lines (default: 200)
  --previous            Show the previous container instance

Examples:
  hv logs                         Select a pod from a numbered menu
  hv logs backend                 Match a pod in the default project
  hv logs pod/backend-abc123      Full kubectl-style pod name is accepted
  hv logs --project myapp -f
EOF
}

PROJECT=""
KEYWORD=""
FOLLOW=false
CONTAINER=""
TAIL=200
PREVIOUS=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project|-n|--namespace) PROJECT="${2:-}"; shift 2 ;;
    -f|--follow) FOLLOW=true; shift ;;
    -c|--container) CONTAINER="${2:-}"; shift 2 ;;
    --tail) TAIL="${2:-}"; shift 2 ;;
    --previous) PREVIOUS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

case "${#POSITIONAL[@]}" in
  0) ;;
  1)
    if [[ -z "$PROJECT" ]] && hv_project_exists "${POSITIONAL[0]}"; then
      PROJECT="${POSITIONAL[0]}"
    else
      KEYWORD="${POSITIONAL[0]}"
    fi
    ;;
  2)
    [[ -z "$PROJECT" ]] || die "Do not combine --project with two positional arguments"
    PROJECT="${POSITIONAL[0]}"
    KEYWORD="${POSITIONAL[1]}"
    ;;
  *) die "Too many arguments" ;;
esac

[[ -n "$PROJECT" ]] || PROJECT="$(hv_default_project || true)"
[[ -n "$PROJECT" ]] || die "Project is required"
hv_validate_project_name "$PROJECT"
[[ "$TAIL" =~ ^[0-9]+$ ]] || die "--tail must be numeric"

POD="$(hv_find_pod "$PROJECT" "$KEYWORD")"
ARGS=(logs "$POD" -n "$PROJECT" --tail "$TAIL")
[[ "$FOLLOW" == true ]] && ARGS+=(-f)
[[ "$PREVIOUS" == true ]] && ARGS+=(--previous)
[[ -n "$CONTAINER" ]] && ARGS+=(-c "$CONTAINER")

info "Logs: $PROJECT/$POD"
hv_kubectl "${ARGS[@]}"
