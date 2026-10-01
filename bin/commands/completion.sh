#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv completion bash|zsh

Examples:
  source <(hv completion bash)
  hv completion bash > ~/.local/share/bash-completion/completions/hv
  hv completion zsh > ~/.zfunc/_hv
EOF
}

case "${1:-}" in
  bash)
    cat "$HV_ROOT/bin/completion/completion.sh"
    ;;
  zsh)
    cat <<'EOF'
#compdef hv
_hv() {
  local -a commands
  commands=(
    'init:prepare HelmVerse'
    'doctor:diagnose tools and networking'
    'project:manage projects'
    'cluster:manage the kind cluster'
    'deploy:deploy a project'
    'status:show deployment status'
    'logs:show pod logs'
    'shell:open a pod shell'
    'rollback:roll back a release'
    'undeploy:uninstall a release'
    'cert:manage certificate infrastructure'
    'config:manage defaults'
    'completion:generate completion'
    'version:show version'
  )
  _describe 'command' commands
}
_hv "$@"
EOF
    ;;
  -h|--help|help|"") usage ;;
  *) die "Unsupported shell: $1" ;;
esac
