#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv shell [pod-keyword] [-p|--project <name>] [-c|--container <name>] [--shell <path>]

Opens an interactive shell. /bin/sh is used by default because it is present
in more container images than bash.

Without a keyword, an interactive numbered pod menu is displayed.
EOF
}

PROJECT=""
KEYWORD=""
CONTAINER=""
SHELL_PATH="/bin/sh"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project|-n|--namespace) PROJECT="${2:-}"; shift 2 ;;
    -c|--container) CONTAINER="${2:-}"; shift 2 ;;
    --shell) SHELL_PATH="${2:-}"; shift 2 ;;
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
POD="$(hv_find_pod "$PROJECT" "$KEYWORD")"

ARGS=(exec -it "$POD" -n "$PROJECT")
[[ -n "$CONTAINER" ]] && ARGS+=(-c "$CONTAINER")
ARGS+=(-- "$SHELL_PATH")

info "Opening $SHELL_PATH in $PROJECT/$POD"
hv_kubectl "${ARGS[@]}"
