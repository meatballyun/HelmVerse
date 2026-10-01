#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

case "${1:-}" in
  ""|-v|--version)
    printf 'hv %s\n' "$(hv_version)"
    ;;
  -h|--help)
    printf 'Usage: hv version\n'
    ;;
  *)
    die "Unknown option: $1"
    ;;
esac
