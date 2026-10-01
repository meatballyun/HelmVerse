#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv k9s [options] [-- <native-k9s-options>]

Open K9s in the current HelmVerse project namespace. When no current project
is configured, or its namespace does not exist, K9s starts in namespace
'default'. Inside K9s, enter ':ns' and press Enter to switch namespaces.

Options:
  -n, --namespace <name>  Override the starting namespace
  -A, --all               Start in all-namespaces mode
      --readonly          Disable cluster modification commands
      --write             Explicitly enable cluster modification commands
  -h, --help              Show this help

Examples:
  hv k9s
  hv k9s --namespace myapp
  hv k9s --all
  hv k9s --readonly
EOF
}

NAMESPACE_OVERRIDE=""
ALL_NAMESPACES=false
ACCESS_MODE=""
K9S_EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      [[ -n "${2:-}" ]] || die "$1 requires a namespace"
      NAMESPACE_OVERRIDE="$2"
      shift 2
      ;;
    -A|--all)
      ALL_NAMESPACES=true
      shift
      ;;
    --readonly|--write)
      [[ -z "$ACCESS_MODE" || "$ACCESS_MODE" == "$1" ]] || \
        die "--readonly and --write cannot be used together"
      ACCESS_MODE="$1"
      shift
      ;;
    --)
      shift
      K9S_EXTRA_ARGS=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (pass native K9s options after --)"
      ;;
  esac
done

if [[ "$ALL_NAMESPACES" == true && -n "$NAMESPACE_OVERRIDE" ]]; then
  die "--all and --namespace cannot be used together"
fi

[[ -t 0 && -t 1 ]] || die "K9s requires an interactive terminal. Reconnect with SSH TTY enabled."

K9S_BINARY="$(hv_find_executable k9s || true)"
[[ -n "$K9S_BINARY" ]] || \
  die "K9s is not installed. Run: hv init --with-k9s"

hv_cluster_exists || die "kind cluster '$(hv_cluster_name)' is not running. Run: hv cluster up"
hv_kube_reachable || die "Kubernetes API is not reachable. Run: hv doctor"

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
[[ -f "$KUBECONFIG_PATH" ]] || \
  die "Kubeconfig was not found: $KUBECONFIG_PATH"

CONTEXT="kind-$(hv_cluster_name)"
K9S_ARGS=(--kubeconfig "$KUBECONFIG_PATH" --context "$CONTEXT")

if [[ "$ALL_NAMESPACES" == true ]]; then
  K9S_ARGS+=(--all-namespaces)
else
  START_NAMESPACE="$NAMESPACE_OVERRIDE"
  if [[ -z "$START_NAMESPACE" ]]; then
    START_NAMESPACE="$(hv_default_project || true)"
  fi
  START_NAMESPACE="${START_NAMESPACE:-default}"
  hv_validate_project_name "$START_NAMESPACE"

  if ! hv_kubectl get namespace "$START_NAMESPACE" >/dev/null 2>&1; then
    warn "Namespace '$START_NAMESPACE' does not exist; starting in 'default'."
    START_NAMESPACE="default"
  fi
  K9S_ARGS+=(--namespace "$START_NAMESPACE")
fi

[[ -z "$ACCESS_MODE" ]] || K9S_ARGS+=("$ACCESS_MODE")
K9S_ARGS+=("${K9S_EXTRA_ARGS[@]}")

if [[ -z "${TERM:-}" || "${TERM:-}" == "dumb" ]]; then
  export TERM=xterm-256color
fi

note "Opening K9s (context: $CONTEXT)..."
exec "$K9S_BINARY" "${K9S_ARGS[@]}"
