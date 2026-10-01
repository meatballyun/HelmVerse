#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../utils/hv_common.sh
source "$SCRIPT_DIR/../../utils/hv_common.sh"

usage() {
  cat <<'EOF'
Usage: hv doctor [--domain <hostname>] [--strict]

Checks required tools, Docker, kind/Kubernetes connectivity, ports 80/443,
stale iptables redirects, DNS resolution, and HTTPS response codes.

Options:
  --domain <host>  Check a hostname. May be provided more than once.
  --strict         Return failure when warnings are found.
EOF
}

FAILURES=0
WARNINGS=0
STRICT=false
DOMAINS=()

pass() { success "$1"; }
diagnostic_warn() { warn "$1"; WARNINGS=$((WARNINGS + 1)); }
diagnostic_fail() { error "$1"; FAILURES=$((FAILURES + 1)); }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      [[ -n "${2:-}" ]] || die "--domain requires a hostname"
      DOMAINS+=("$2")
      shift 2
      ;;
    --strict)
      STRICT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

headline "HelmVerse doctor"

for tool in git docker helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool is installed"
  else
    diagnostic_fail "$tool is not installed"
  fi
done

if command -v kind >/dev/null 2>&1; then
  pass "kind is installed"
else
  diagnostic_warn "kind is not in PATH; an existing cluster can still be inspected through Docker"
fi

if command -v kubectl >/dev/null 2>&1; then
  pass "kubectl is installed"
else
  diagnostic_warn "kubectl is not in PATH; hv will use the kind control-plane fallback when available"
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is reachable"
  else
    diagnostic_fail "Docker is installed but the daemon is not reachable"
  fi
fi

if hv_cluster_exists; then
  pass "kind cluster '$(hv_cluster_name)' is running"
  if hv_kube_reachable; then
    pass "Kubernetes API is reachable"
  else
    diagnostic_fail "Kubernetes API is not reachable"
  fi
else
  diagnostic_fail "kind cluster '$(hv_cluster_name)' is not running"
fi

if command -v ss >/dev/null 2>&1; then
  for port in 80 443; do
    if ss -lntH 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
      pass "TCP port $port is listening"
    else
      diagnostic_fail "TCP port $port is not listening"
    fi
  done
else
  diagnostic_warn "ss is unavailable; ports 80 and 443 were not inspected"
fi

if command -v iptables >/dev/null 2>&1; then
  IPTABLES_OUTPUT="$(sudo -n iptables -t nat -S PREROUTING 2>/dev/null || true)"
  if [[ -n "$IPTABLES_OUTPUT" ]]; then
    if printf '%s\n' "$IPTABLES_OUTPUT" | grep -Eq -- '--dport (80|443).*REDIRECT'; then
      diagnostic_fail "PREROUTING contains a REDIRECT for port 80 or 443; it can bypass Docker publishing"
      printf '%s\n' "$IPTABLES_OUTPUT" | grep -E -- '--dport (80|443).*REDIRECT' >&2
    else
      pass "No stale PREROUTING redirect was found for ports 80/443"
    fi
  else
    diagnostic_warn "iptables PREROUTING could not be read without an interactive sudo password"
  fi
fi

if [[ ${#DOMAINS[@]} -eq 0 ]] && hv_kube_reachable; then
  while IFS= read -r host; do
    [[ -n "$host" ]] && DOMAINS+=("$host")
  done < <(hv_kubectl get ingress -A -o jsonpath='{range .items[*].spec.rules[*]}{.host}{"\n"}{end}' 2>/dev/null | sort -u)
fi

for domain in "${DOMAINS[@]}"; do
  if command -v getent >/dev/null 2>&1 && getent ahostsv4 "$domain" >/dev/null 2>&1; then
    pass "$domain resolves through DNS"
  else
    diagnostic_fail "$domain does not resolve through DNS"
    continue
  fi

  if command -v curl >/dev/null 2>&1; then
    HTTP_CODE="$(curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "https://$domain" 2>/dev/null || true)"
    case "$HTTP_CODE" in
      2??|3??) pass "https://$domain returned HTTP $HTTP_CODE" ;;
      000|"") diagnostic_fail "https://$domain could not be reached" ;;
      *) diagnostic_fail "https://$domain returned HTTP $HTTP_CODE" ;;
    esac
  fi
done

echo
printf 'Result: %d failure(s), %d warning(s)\n' "$FAILURES" "$WARNINGS"

if [[ "$FAILURES" -gt 0 ]] || { [[ "$STRICT" == true ]] && [[ "$WARNINGS" -gt 0 ]]; }; then
  exit 1
fi
