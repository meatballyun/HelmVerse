#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv init [options]

Options:
  --install-tools     Install missing Docker, kubectl, kind, and Helm
  --with-k9s          Install the optional K9s terminal UI when missing
  --configure-shell   Configure direnv for the current shell
  -y, --yes           Skip required-tool confirmation; does not imply --with-k9s

Without options, init creates only the safe HelmVerse defaults and reports
missing required tools. In an interactive terminal it also offers to install
optional K9s. It does not modify shell startup files.
EOF
}

INSTALL_TOOLS=false
WITH_K9S=false
CONFIGURE_SHELL=false
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-tools) INSTALL_TOOLS=true; shift ;;
    --with-k9s) WITH_K9S=true; shift ;;
    --configure-shell) CONFIGURE_SHELL=true; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

headline "Initialize HelmVerse"
printf 'Root: %s\n' "$HV_ROOT"

if [[ ! -f "$HV_CONFIG_FILE" ]]; then
  hv_config_set KIND_DEFAULT_CLUSTER_NAME "$(hv_cluster_name)"
  success "Created $HV_CONFIG_FILE"
else
  success "Configuration already exists: $HV_CONFIG_FILE"
fi

MISSING_TOOLS=()
for tool in docker kubectl kind helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    success "$tool is installed"
  else
    warn "$tool is missing"
    MISSING_TOOLS+=("$tool")
  fi
done

install_tool() {
  case "$1" in
    docker) "$HV_ROOT/scripts/docker/install_docker.sh" ;;
    kubectl) "$HV_ROOT/scripts/kubectl/install_kubectl.sh" ;;
    kind) "$HV_ROOT/scripts/kind/install_kind.sh" ;;
    helm) "$HV_ROOT/scripts/helm/install_helm.sh" ;;
    k9s) "$HV_ROOT/scripts/k9s/install_k9s.sh" ;;
    *) die "No installer is configured for $1" ;;
  esac
}

if [[ "$INSTALL_TOOLS" == true && ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  printf 'Missing tools: %s\n' "${MISSING_TOOLS[*]}"
  if [[ "$ASSUME_YES" != true ]] && ! hv_confirm "Install the missing host tools?"; then
    note "Installation cancelled."
  else
    for tool in "${MISSING_TOOLS[@]}"; do
      headline "Install $tool"
      install_tool "$tool"
    done
  fi
elif [[ "$INSTALL_TOOLS" == true ]]; then
  success "All required tools are already installed."
fi

if K9S_BINARY="$(hv_find_executable k9s)"; then
  success "K9s is installed: $K9S_BINARY"
else
  note "K9s is optional and is not installed."
  if [[ "$WITH_K9S" == true ]]; then
    headline "Install K9s"
    install_tool k9s
  elif [[ "$ASSUME_YES" != true && -t 0 && -t 1 ]] && \
       hv_confirm "Install the optional K9s terminal UI?"; then
    headline "Install K9s"
    install_tool k9s
  else
    note "Skipped K9s. Install it later with: hv init --with-k9s"
  fi
fi

if [[ "$CONFIGURE_SHELL" == true ]]; then
  hv_require_command direnv
  (cd "$HV_ROOT" && "$HV_ROOT/scripts/helmverse/setup_direnv.sh")
fi

echo
note "Next: run 'hv doctor', then 'hv cluster up'."
