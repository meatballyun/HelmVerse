#!/usr/bin/env bash

# Shared helpers for the hv command line interface. Keep this file safe to
# source from scripts that already enabled strict mode.

if [[ -z "${HV_ROOT:-}" ]]; then
  HV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export HV_ROOT

# shellcheck source=logger.sh
source "$HV_ROOT/utils/logger.sh"

HV_PROJECTS_DIR="${HV_PROJECTS_DIR:-$HV_ROOT/projects}"
HV_CONFIG_FILE="${HV_CONFIG_FILE:-$HV_ROOT/.env}"

hv_version() {
  local version="unknown"
  if [[ -f "$HV_ROOT/config.json" ]]; then
    version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$HV_ROOT/config.json" | head -n 1)"
  fi
  printf '%s\n' "${version:-unknown}"
}

hv_require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || die "Required command is missing: $command_name"
}

hv_find_executable() {
  local command_name="$1"
  local executable

  executable="$(command -v "$command_name" 2>/dev/null || true)"
  if [[ -n "$executable" ]]; then
    printf '%s\n' "$executable"
    return 0
  fi

  executable="${HV_LOCAL_BIN_DIR:-$HOME/.local/bin}/$command_name"
  if [[ -x "$executable" ]]; then
    printf '%s\n' "$executable"
    return 0
  fi

  return 1
}

hv_validate_project_name() {
  local name="$1"
  [[ "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || \
    die "Invalid project name '$name'. Use lowercase letters, numbers, and hyphens."
}

hv_project_dir() {
  printf '%s/%s\n' "$HV_PROJECTS_DIR" "$1"
}

hv_chart_dir() {
  printf '%s/helm-chart\n' "$(hv_project_dir "$1")"
}

hv_project_exists() {
  [[ -d "$(hv_project_dir "$1")" && -f "$(hv_chart_dir "$1")/Chart.yaml" ]]
}

hv_require_project() {
  local project="$1"
  hv_validate_project_name "$project"
  hv_project_exists "$project" || die "Project '$project' does not contain helm-chart/Chart.yaml."
}

hv_list_projects() {
  [[ -d "$HV_PROJECTS_DIR" ]] || return 0
  local directory
  for directory in "$HV_PROJECTS_DIR"/*; do
    [[ -d "$directory" && -f "$directory/helm-chart/Chart.yaml" ]] || continue
    basename "$directory"
  done | sort
}

hv_config_get() {
  local key="$1"
  [[ -f "$HV_CONFIG_FILE" ]] || return 1
  sed -n "s/^${key}=//p" "$HV_CONFIG_FILE" | tail -n 1
}

hv_config_set() {
  local key="$1"
  local value="$2"
  local temporary

  [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "Invalid configuration key: $key"
  mkdir -p "$(dirname "$HV_CONFIG_FILE")"
  temporary="$(mktemp)"

  if [[ -f "$HV_CONFIG_FILE" ]]; then
    grep -v "^${key}=" "$HV_CONFIG_FILE" > "$temporary" || true
  fi
  printf '%s=%s\n' "$key" "$value" >> "$temporary"
  mv "$temporary" "$HV_CONFIG_FILE"
}

hv_default_project() {
  local configured="${NAMESPACE:-}"
  if [[ -z "$configured" ]]; then
    configured="$(hv_config_get NAMESPACE 2>/dev/null || true)"
  fi
  [[ -n "$configured" ]] && printf '%s\n' "$configured"
}

hv_cluster_name() {
  local configured="${KIND_DEFAULT_CLUSTER_NAME:-}"
  if [[ -z "$configured" ]]; then
    configured="$(hv_config_get KIND_DEFAULT_CLUSTER_NAME 2>/dev/null || true)"
  fi
  if [[ -z "$configured" && -f "$HV_ROOT/config/kind-config.yaml" ]]; then
    configured="$(sed -n 's/^name:[[:space:]]*//p' "$HV_ROOT/config/kind-config.yaml" | head -n 1 | tr -d '"')"
  fi
  printf '%s\n' "${configured:-helmverse}"
}

hv_cluster_node() {
  printf '%s-control-plane\n' "$(hv_cluster_name)"
}

hv_cluster_exists() {
  local cluster_name
  cluster_name="$(hv_cluster_name)"

  if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -Fxq "$cluster_name"; then
    return 0
  fi

  command -v docker >/dev/null 2>&1 && \
    [[ "$(docker inspect -f '{{.State.Running}}' "$(hv_cluster_node)" 2>/dev/null || true)" == "true" ]]
}

hv_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    command kubectl "$@"
    return
  fi

  local node
  local docker_exec_args=(exec)
  node="$(hv_cluster_node)"
  if command -v docker >/dev/null 2>&1 && \
     [[ "$(docker inspect -f '{{.State.Running}}' "$node" 2>/dev/null || true)" == "true" ]]; then
    if [[ "${1:-}" == "exec" ]]; then
      for argument in "$@"; do
        if [[ "$argument" == "-it" || "$argument" == "-ti" || "$argument" == "-t" ]]; then
          [[ -t 0 && -t 1 ]] || die "Interactive pod exec requires a terminal."
          docker_exec_args+=(-it)
          break
        fi
      done
    fi
    docker "${docker_exec_args[@]}" -e KUBECONFIG=/etc/kubernetes/admin.conf "$node" kubectl "$@"
    return
  fi

  die "kubectl is unavailable and no running kind control-plane fallback was found."
}

hv_kube_reachable() {
  hv_kubectl cluster-info >/dev/null 2>&1
}

hv_find_pod() {
  local namespace="$1"
  local keyword="${2:-}"
  local all_pods=()
  local matched_pods=()
  local pod
  local choice
  local index
  local selection

  keyword="${keyword#pod/}"
  while IFS= read -r pod; do
    [[ -n "$pod" ]] && all_pods+=("${pod#pod/}")
  done < <(hv_kubectl get pods -n "$namespace" -o name 2>/dev/null || true)
  [[ ${#all_pods[@]} -gt 0 ]] || die "No pods found in namespace '$namespace'."

  if [[ -n "$keyword" ]]; then
    for pod in "${all_pods[@]}"; do
      if [[ "$pod" == "$keyword" ]]; then
        printf '%s\n' "$pod"
        return 0
      fi
      [[ "$pod" == *"$keyword"* ]] && matched_pods+=("$pod")
    done
    [[ ${#matched_pods[@]} -gt 0 ]] || die "No pod in '$namespace' matches '$keyword'."
  else
    matched_pods=("${all_pods[@]}")
  fi

  if [[ ${#matched_pods[@]} -eq 1 ]]; then
    printf '%s\n' "${matched_pods[0]}"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    printf 'Matching pods in namespace %s:\n' "$namespace" >&2
    printf '  %s\n' "${matched_pods[@]}" >&2
    die "More than one pod matched in non-interactive mode. Provide a pod keyword."
  fi

  printf 'Available pods in namespace %s:\n' "$namespace" >&2
  for index in "${!matched_pods[@]}"; do
    printf '  %d) %s\n' "$((index + 1))" "${matched_pods[$index]}" >&2
  done

  while true; do
    read -r -p "Select a pod by number or name (q to cancel): " choice
    choice="${choice#pod/}"
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
      note "Selection cancelled." >&2
      return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      selection=$((10#$choice))
      if (( selection >= 1 && selection <= ${#matched_pods[@]} )); then
        printf '%s\n' "${matched_pods[$((selection - 1))]}"
        return 0
      fi
    fi

    for pod in "${matched_pods[@]}"; do
      if [[ "$choice" == "$pod" ]]; then
        printf '%s\n' "$pod"
        return 0
      fi
    done
    warn "Invalid selection: $choice" >&2
  done
}

hv_confirm() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

hv_warn_deprecated() {
  warn "$1 is deprecated. $2"
}
