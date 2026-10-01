#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv deploy [<project>] [project options]

Runs the project's helm-chart/deploy.sh. The project controls Helm, SOPS,
validation and deployment defaults. Without a project, shows an interactive menu.

Project options: --env, --values (-f), --set, --secrets-file, --timeout,
                 --dry-run, --no-wait, --no-atomic
Use -- to forward additional project-specific arguments.
EOF
}

select_project_interactively() {
  local projects=()
  local choice=""
  local candidate=""
  local index
  local selection

  while IFS= read -r candidate; do
    [[ -n "$candidate" && "$candidate" != "my-project" ]] && projects+=("$candidate")
  done < <(hv_list_projects)

  [[ ${#projects[@]} -gt 0 ]] || die "No deployable projects were found in $HV_PROJECTS_DIR"

  if [[ ! -t 0 ]]; then
    printf 'Available projects:\n' >&2
    for index in "${!projects[@]}"; do
      printf '  %d) %s\n' "$((index + 1))" "${projects[$index]}" >&2
    done
    die "Project is required in non-interactive mode: hv deploy <project>"
  fi

  printf 'Available projects:\n'
  for index in "${!projects[@]}"; do
    printf '  %d) %s\n' "$((index + 1))" "${projects[$index]}"
  done

  while true; do
    read -r -p "Select a project by number or name (q to cancel): " choice
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
      note "Deployment cancelled."
      exit 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      selection=$((10#$choice))
      if (( selection >= 1 && selection <= ${#projects[@]} )); then
        PROJECT="${projects[$((selection - 1))]}"
        break
      fi
    fi

    for candidate in "${projects[@]}"; do
      if [[ "$choice" == "$candidate" ]]; then
        PROJECT="$candidate"
        break 2
      fi
    done

    warn "Invalid selection: $choice"
  done

  success "Selected project: $PROJECT"
}

PROJECT=""
PROJECT_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|--timeout|--values|-f|--set|--secrets-file)
      [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
      PROJECT_ARGS+=("$1" "$2"); shift 2 ;;
    --dry-run|--no-wait|--no-atomic)
      PROJECT_ARGS+=("$1"); shift ;;
    --with-cert)
      hv_warn_deprecated "--with-cert" "Certificates are managed by the project chart."
      shift ;;
    --) shift; PROJECT_ARGS+=("$@"); break ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown routing option: $1; use -- for custom project arguments" ;;
    *) [[ -z "$PROJECT" ]] || die "Only one project may be specified"; PROJECT="$1"; shift ;;
  esac
done
[[ -n "$PROJECT" ]] || select_project_interactively
hv_require_project "$PROJECT"
CHART="$(hv_chart_dir "$PROJECT")"
[[ -x "$CHART/deploy.sh" ]] || die "Project deployment script is missing or not executable: $CHART/deploy.sh"
headline "Project deployment: $PROJECT"
exec env HV_PROJECT_NAME="$PROJECT" "$CHART/deploy.sh" "${PROJECT_ARGS[@]}"
