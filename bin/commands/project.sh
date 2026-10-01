#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage:
  hv project list
  hv project show <project>
  hv project validate <project> [--env dev|prod]
  hv project create <project> --host <hostname> [--image <image>] [--port <port>]

Project names become the default Helm release and Kubernetes namespace names.
Environment-specific values are loaded from values.<env>.yaml when present.
EOF
}

cmd_list() {
  local found=false
  while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    found=true
    if [[ "$project" == "my-project" ]]; then
      printf '%-24s %s\n' "$project" '(template)'
    else
      printf '%s\n' "$project"
    fi
  done < <(hv_list_projects)
  [[ "$found" == true ]] || note "No projects were found in $HV_PROJECTS_DIR"
}

cmd_show() {
  local project="$1"
  local chart
  hv_require_project "$project"
  chart="$(hv_chart_dir "$project")"

  printf 'name: %s\n' "$project"
  printf 'namespace: %s\n' "$project"
  printf 'release: %s\n' "$project"
  printf 'chart: %s\n' "$chart"
  printf 'values:\n'
  find "$chart" -maxdepth 1 -type f -name 'values*.yaml' -printf '  - %f\n' | sort
  printf 'hosts:\n'
  sed -nE 's/^[[:space:]]*(- )?host:[[:space:]]*/  - /p' "$chart"/values*.yaml 2>/dev/null | tr -d "\"'" | sort -u || true
}

cmd_validate() {
  local project="$1"
  shift
  "$SCRIPT_DIR/deploy.sh" "$project" --dry-run "$@"
}

cmd_create() {
  local project="$1"
  shift
  local host=""
  local image="nginx"
  local port="80"
  local template="$HV_PROJECTS_DIR/my-project"
  local target

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host) host="${2:-}"; shift 2 ;;
      --image) image="${2:-}"; shift 2 ;;
      --port) port="${2:-}"; shift 2 ;;
      -h|--help) usage; return 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  hv_validate_project_name "$project"
  [[ -n "$host" ]] || die "--host is required"
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid hostname: $host"
  [[ "$image" != *'|'* ]] || die "Image name contains an unsupported character"
  [[ "$port" =~ ^[0-9]+$ ]] || die "--port must be numeric"
  [[ -d "$template/helm-chart" ]] || die "Project template is missing: $template"

  target="$(hv_project_dir "$project")"
  [[ ! -e "$target" ]] || die "Project already exists: $target"

  cp -R "$template" "$target"
  find "$target/helm-chart" -type f -exec sed -i \
    -e "s|my-sample-chart|$project|g" \
    -e "s|example-local|$project|g" \
    -e "s|example.local|$host|g" {} +
  sed -i \
    -e "s|^  repository:.*|  repository: $image|" \
    -e "s|^  port:.*|  port: $port|" \
    "$target/helm-chart/values.yaml"
  cat > "$target/project.env" <<EOF
PROJECT_NAME=$project
DEPLOY_ENV=dev
EOF

  success "Created project '$project' at $target"
  note "Review values.yaml, then run: hv project validate $project"
}

SUBCOMMAND="${1:-list}"
[[ $# -eq 0 ]] || shift

case "$SUBCOMMAND" in
  list|ls) cmd_list ;;
  show)
    [[ $# -eq 1 ]] || die "Usage: hv project show <project>"
    cmd_show "$1"
    ;;
  validate)
    [[ $# -ge 1 ]] || die "Usage: hv project validate <project> [--env dev|prod]"
    PROJECT="$1"
    shift
    cmd_validate "$PROJECT" "$@"
    ;;
  create|new)
    [[ $# -ge 1 ]] || die "Usage: hv project create <project> --host <hostname>"
    PROJECT="$1"
    shift
    cmd_create "$PROJECT" "$@"
    ;;
  help|-h|--help) usage ;;
  *) die "Unknown project command: $SUBCOMMAND" ;;
esac
