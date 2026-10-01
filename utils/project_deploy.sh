#!/usr/bin/env bash
# Functions used explicitly by each project's deploy.sh.
# shellcheck source=hv_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hv_common.sh"

project_deploy_init() {
  set +x
  CHART_DIR="$(cd "$(dirname "$1")" && pwd)"
  PROJECT_DIR="$(dirname "$CHART_DIR")"
  PROJECT_NAME="${HV_PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
  ENVIRONMENT="${3:-dev}"
  TIMEOUT="${2:-5m}"
  DRY_RUN=false
  WAIT=true
  WAIT_FOR_JOBS=false
  ATOMIC=true
  SECRETS_FILE=""
  SECRETS_FILE_EXPLICIT=false
  EXTRA_VALUES=()
  SET_VALUES=()
  unset hv_secret_values
  hv_secret_values=""
  trap 'unset hv_secret_values' EXIT
}

project_deploy_usage() {
  cat <<EOF
Usage: ./deploy.sh [options]
  --env dev|prod       Environment (project default: $ENVIRONMENT)
  -f, --values FILE    Extra values; relative to the chart directory
  --set KEY=VALUE      Non-secret Helm overrides; repeatable
  --secrets-file FILE  Encrypted values; relative to the project directory
  --timeout DURATION  Helm timeout (project default: $TIMEOUT)
  --dry-run           Validate and render without changing the cluster
  --no-atomic         Disable automatic rollback
  --no-wait           Disable waiting and automatic rollback

The project decides whether to load SOPS and which values are required.
EOF
}

project_deploy_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env|--timeout|--secrets-file|-f|--values|--set)
        [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
        case "$1" in
          --env) ENVIRONMENT="$2" ;;
          --timeout) TIMEOUT="$2" ;;
          --secrets-file) SECRETS_FILE="$2"; SECRETS_FILE_EXPLICIT=true ;;
          -f|--values) EXTRA_VALUES+=("$2") ;;
          --set)
            [[ "$2" == *=* ]] || die "--set expects KEY=VALUE"
            case "$2" in
              secret=*|secret.*|secret\[*|*,secret=*|*,secret.*|*,secret\[*)
                die "Use encrypted values for secret fields; do not pass them with --set" ;;
            esac
            SET_VALUES+=("$2") ;;
        esac
        shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      --no-atomic) ATOMIC=false; shift ;;
      --no-wait) WAIT=false; ATOMIC=false; shift ;;
      -h|--help) project_deploy_usage; exit 0 ;;
      *) die "Unknown project deployment argument: $1" ;;
    esac
  done
  [[ "$ENVIRONMENT" == dev || "$ENVIRONMENT" == prod ]] || die "--env must be dev or prod"
  if [[ -z "$SECRETS_FILE" ]]; then
    SECRETS_FILE="$PROJECT_DIR/secrets/values.$ENVIRONMENT.enc.yaml"
  elif [[ "$SECRETS_FILE" != /* ]]; then
    SECRETS_FILE="$PROJECT_DIR/$SECRETS_FILE"
  fi
}

project_deploy_load_sops() {
  local sops_bin
  sops_bin="$(hv_find_executable sops)" || die "SOPS is missing; run hv sops init"
  hv_require_command python3
  if ! hv_secret_values="$("$sops_bin" decrypt --output-type json "$SECRETS_FILE")"; then
    die "SOPS decryption failed; deployment stopped"
  fi
  printf '%s\n' "$hv_secret_values" | python3 "$HV_ROOT/utils/sops_values.py" validate ||
    die "Invalid secret values; deployment stopped"
}

project_deploy_require_secrets() {
  local payload="$hv_secret_values"
  [[ -n "$payload" ]] || payload='{"secret":{}}'
  printf '%s\n' "$payload" |
    python3 "$HV_ROOT/utils/sops_values.py" validate "$@"
}

project_deploy_require_cluster() {
  [[ "$DRY_RUN" == true ]] && return 0
  hv_cluster_exists || die "Cluster '$(hv_cluster_name)' is not running. Run hv cluster up first."
  hv_kube_reachable || die "Kubernetes API is not reachable. Run hv doctor for details."
}

project_deploy_run() {
  hv_require_command helm
  local values_file value
  local values_args=(--values "$CHART_DIR/values.yaml")
  [[ ! -f "$CHART_DIR/values.$ENVIRONMENT.yaml" ]] || values_args+=(--values "$CHART_DIR/values.$ENVIRONMENT.yaml")
  for values_file in "${EXTRA_VALUES[@]}"; do
    [[ "$values_file" == /* ]] || values_file="$CHART_DIR/$values_file"
    [[ -f "$values_file" ]] || die "Values file not found: $values_file"
    values_args+=(--values "$values_file")
  done
  local set_args=(--set-string "projectName=$PROJECT_NAME" --set-string "projectDir=/projects/$PROJECT_NAME" --set-string "deployEnv=$ENVIRONMENT")
  for value in "${SET_VALUES[@]}"; do set_args+=(--set "$value"); done
  # Decrypted values are never arguments, exported variables, or disk files.
  project_helm() {
    if [[ -n "$hv_secret_values" ]]; then
      printf '%s\n' "$hv_secret_values" | helm "$@" "${values_args[@]}" --values - "${set_args[@]}"
    else
      helm "$@" "${values_args[@]}" "${set_args[@]}"
    fi
  }
  project_helm lint "$CHART_DIR"
  if [[ "$DRY_RUN" == true ]]; then
    project_helm template "$PROJECT_NAME" "$CHART_DIR" --namespace "$PROJECT_NAME" >/dev/null
    success "Dry run completed. No cluster resources were changed."
    return 0
  fi
  local helm_args=(upgrade "$PROJECT_NAME" "$CHART_DIR" --install --namespace "$PROJECT_NAME" --create-namespace --history-max 10 --timeout "$TIMEOUT")
  [[ "$WAIT" == false ]] || helm_args+=(--wait)
  [[ "$WAIT" == false || "$WAIT_FOR_JOBS" == false ]] || helm_args+=(--wait-for-jobs)
  [[ "$ATOMIC" == false ]] || helm_args+=(--atomic)
  project_helm "${helm_args[@]}"
}
