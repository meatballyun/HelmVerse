#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage:
  hv cluster up [--with-addons]
  hv cluster status
  hv cluster down [--yes]
  hv cluster addon install ingress|cert-manager
  hv cluster addon status
  hv cluster addon remove ingress [--yes]

'down' removes the whole kind cluster and therefore requires confirmation.
EOF
}

cmd_up() {
  local with_addons=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-addons) with_addons=true; shift ;;
      -h|--help) usage; return 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  hv_require_command docker
  if hv_cluster_exists; then
    success "Cluster '$(hv_cluster_name)' is already running."
    if [[ "$with_addons" == true ]]; then
      "$SCRIPT_DIR/nginx.sh" install
      "$SCRIPT_DIR/cert.sh" install
    fi
    return 0
  fi

  hv_require_command kind
  (cd "$HV_ROOT" && "$HV_ROOT/scripts/kind/create_kind_cluster.sh")

  if [[ "$with_addons" == true ]]; then
    "$SCRIPT_DIR/nginx.sh" install
    "$SCRIPT_DIR/cert.sh" install
  fi

  success "Cluster '$(hv_cluster_name)' is ready."
}

cmd_status() {
  printf 'Cluster: %s\n' "$(hv_cluster_name)"
  if ! hv_cluster_exists; then
    error "State: not running"
    return 1
  fi
  success "State: running"
  hv_kubectl get nodes -o wide
  echo
  hv_kubectl get pods -A
}

cmd_down() {
  local assume_yes=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) assume_yes=true; shift ;;
      -h|--help) usage; return 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  hv_require_command kind
  if ! hv_cluster_exists; then
    note "Cluster '$(hv_cluster_name)' is already absent."
    return 0
  fi

  if [[ "$assume_yes" != true ]] && ! hv_confirm "Delete kind cluster '$(hv_cluster_name)' and all workloads?"; then
    note "Cancelled."
    return 0
  fi

  kind delete cluster --name "$(hv_cluster_name)"
  success "Cluster deleted."
}

cmd_addon() {
  local action="${1:-status}"
  [[ $# -eq 0 ]] || shift
  local addon="${1:-}"
  [[ $# -eq 0 ]] || shift
  local assume_yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes) assume_yes=true; shift ;;
      -h|--help) usage; return 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  case "$action:$addon" in
    status:)
      headline "Ingress"
      hv_kubectl get deployment,pod,service -n ingress-nginx 2>/dev/null || note "ingress-nginx is not installed"
      headline "cert-manager"
      hv_kubectl get deployment,pod -n cert-manager 2>/dev/null || note "cert-manager is not installed"
      ;;
    install:ingress|install:nginx)
      "$SCRIPT_DIR/nginx.sh" install
      ;;
    install:cert-manager|install:cert)
      "$SCRIPT_DIR/cert.sh" install
      ;;
    remove:ingress|remove:nginx)
      if [[ "$assume_yes" != true ]] && ! hv_confirm "Remove the ingress-nginx add-on?"; then
        note "Cancelled."
        return 0
      fi
      "$SCRIPT_DIR/nginx.sh" remove
      ;;
    remove:cert-manager|remove:cert)
      die "Automatic cert-manager removal is intentionally unsupported because it can remove active certificate resources."
      ;;
    *)
      die "Usage: hv cluster addon install|remove ingress|cert-manager, or hv cluster addon status"
      ;;
  esac
}

SUBCOMMAND="${1:-status}"
[[ $# -eq 0 ]] || shift

case "$SUBCOMMAND" in
  up|create) cmd_up "$@" ;;
  status|ls) cmd_status ;;
  down|delete) cmd_down "$@" ;;
  addon|addons) cmd_addon "$@" ;;
  help|-h|--help) usage ;;
  *) die "Unknown cluster command: $SUBCOMMAND" ;;
esac
