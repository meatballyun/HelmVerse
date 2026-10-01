#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$ROOT_DIR/utils/hv_common.sh"

if K9S_BINARY="$(hv_find_executable k9s)"; then
  success "K9s is installed: $("$K9S_BINARY" version 2>/dev/null | head -n 1)"
  exit 0
fi

info "K9s is not installed."
exit 1
