#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage:
  hv pod list [namespace]
  hv pod logs <keyword> [-n namespace]
  hv pod exec <keyword> [-n namespace]
  hv pod describe <keyword> [-n namespace]
  hv pod delete <keyword> [-n namespace] [--yes]

Compatibility command. Prefer hv status, hv logs, and hv shell.
EOF
}

SUBCOMMAND="${1:-help}"
[[ $# -eq 0 ]] || shift
NAMESPACE="$(hv_default_project || true)"
KEYWORD=""
ASSUME_YES=false
REMAINING=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="${2:-}"; shift 2 ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *) REMAINING+=("$1"); shift ;;
  esac
done

case "$SUBCOMMAND" in
  help|-h|--help) usage ;;
  list|ls)
    [[ ${#REMAINING[@]} -eq 0 ]] || NAMESPACE="${REMAINING[0]}"
    [[ -n "$NAMESPACE" ]] || NAMESPACE=default
    hv_kubectl get pods -n "$NAMESPACE" -o wide
    ;;
  logs|exec|describe|desc|delete|del)
    [[ ${#REMAINING[@]} -eq 1 ]] || die "A pod keyword is required"
    [[ -n "$NAMESPACE" ]] || NAMESPACE=default
    KEYWORD="${REMAINING[0]}"
    POD="$(hv_find_pod "$NAMESPACE" "$KEYWORD")"
    case "$SUBCOMMAND" in
      logs) exec "$SCRIPT_DIR/logs.sh" "$NAMESPACE" "$KEYWORD" --follow ;;
      exec) exec "$SCRIPT_DIR/shell.sh" "$NAMESPACE" "$KEYWORD" ;;
      describe|desc) hv_kubectl describe pod "$POD" -n "$NAMESPACE" ;;
      delete|del)
        if [[ "$ASSUME_YES" != true ]] && ! hv_confirm "Delete pod '$NAMESPACE/$POD'?"; then
          note "Cancelled."
          exit 0
        fi
        hv_kubectl delete pod "$POD" -n "$NAMESPACE"
        ;;
    esac
    ;;
  *) die "Unknown pod command: $SUBCOMMAND" ;;
esac
