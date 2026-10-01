#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$ROOT_DIR/utils/hv_common.sh"

if K9S_BINARY="$(hv_find_executable k9s)"; then
  success "K9s is already installed: $K9S_BINARY"
  "$K9S_BINARY" version
  exit 0
fi

hv_require_command curl
hv_require_command tar
hv_require_command sha256sum

K9S_VERSION="${K9S_VERSION:-$(sed -n 's/.*"k9s"[[:space:]]*:[[:space:]]*"[\^~]*\([^"]*\)".*/\1/p' "$ROOT_DIR/config.json" | head -n 1)}"
[[ -n "$K9S_VERSION" ]] || die "K9s version is missing from config.json"
[[ "$K9S_VERSION" == v* ]] || K9S_VERSION="v$K9S_VERSION"

case "$(uname -s)" in
  Linux) OS_TYPE="Linux" ;;
  *) die "K9s automatic installation currently supports Linux only." ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH_TYPE="amd64" ;;
  aarch64|arm64) ARCH_TYPE="arm64" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac

INSTALL_DIR="${K9S_INSTALL_DIR:-$HOME/.local/bin}"
ARCHIVE="k9s_${OS_TYPE}_${ARCH_TYPE}.tar.gz"
RELEASE_BASE="${K9S_RELEASE_BASE_URL:-https://github.com/derailed/k9s/releases/download/$K9S_VERSION}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

info "Downloading K9s $K9S_VERSION for $OS_TYPE/$ARCH_TYPE..."
curl -fsSL -o "$TEMP_DIR/$ARCHIVE" "$RELEASE_BASE/$ARCHIVE"
curl -fsSL -o "$TEMP_DIR/checksums.sha256" "$RELEASE_BASE/checksums.sha256"

EXPECTED_SHA="$(awk -v file="$ARCHIVE" '{ name=$2; sub(/^\*/, "", name); if (name == file) { print $1; exit } }' "$TEMP_DIR/checksums.sha256")"
[[ -n "$EXPECTED_SHA" ]] || die "No checksum was published for $ARCHIVE"
ACTUAL_SHA="$(sha256sum "$TEMP_DIR/$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || die "Checksum verification failed for $ARCHIVE"
success "K9s archive checksum verified."

tar -xzf "$TEMP_DIR/$ARCHIVE" -C "$TEMP_DIR" k9s
mkdir -p "$INSTALL_DIR"
install -m 0755 "$TEMP_DIR/k9s" "$INSTALL_DIR/k9s"

success "K9s installed at $INSTALL_DIR/k9s"
"$INSTALL_DIR/k9s" version

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  note "$INSTALL_DIR is not currently in PATH; hv k9s can still find this installation."
fi
