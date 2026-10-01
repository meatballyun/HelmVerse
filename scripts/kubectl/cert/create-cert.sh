#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../utils/hv_common.sh
source "$SCRIPT_DIR/../../../utils/hv_common.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory of the current script
function usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  install-manager           Install cert-manager
  create-issuer            Create a ClusterIssuer
  create-certificate       Create a Certificate
  help                     Show this help message

Options for create-issuer:
  --email <email>          Email for Let's Encrypt notifications (required)
  --issuer-name <name>     Name of the ClusterIssuer (default: letsencrypt-prod)
  --server <url>           ACME server URL (default: Let's Encrypt production)
  --ingress-class <class>  Ingress class for HTTP01 challenge (default: nginx)

Options for create-certificate:
  --cert-name <name>       Name of the Certificate resource (required)
  --domain <domain>        Domain name for the certificate (required)
  --namespace <namespace>  Namespace for the Certificate (default: ingress-nginx)
  --secret-name <name>     Name of the secret to store the certificate (default: <cert-name>-secret)
  --issuer-name <name>     Name of the ClusterIssuer to use (default: letsencrypt-prod)

Examples:
  # Install cert-manager
  $0 install-manager

  # Create a ClusterIssuer
  $0 create-issuer --email admin@example.com

  # Create a Certificate
  $0 create-certificate --cert-name myapp-tls --domain myapp.example.com

  # Create a Certificate with custom options
  $0 create-certificate --cert-name myapp-tls --domain myapp.example.com \\
    --namespace default --secret-name myapp-tls-secret --issuer-name my-issuer

EOF
  exit 1
}

function install_manager() {
  echo -e "${GREEN}Installing Cert-Manager...${NC}"
  "$SCRIPT_DIR"/install-cert-manager.sh
}

function create_issuer() {
  local EMAIL=""
  local ISSUER_NAME="letsencrypt-prod"
  local SERVER="https://acme-v02.api.letsencrypt.org/directory"
  local INGRESS_CLASS="nginx"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --email)
        EMAIL="$2"
        shift 2
        ;;
      --issuer-name)
        ISSUER_NAME="$2"
        shift 2
        ;;
      --server)
        SERVER="$2"
        shift 2
        ;;
      --ingress-class)
        INGRESS_CLASS="$2"
        shift 2
        ;;
      *)
        echo -e "${RED}[ERROR] Unknown option: $1${NC}" >&2
        usage
        ;;
    esac
  done

  if [ -z "$EMAIL" ]; then
    echo -e "${RED}[ERROR] --email is required${NC}" >&2
    usage
  fi

  echo -e "${GREEN}Creating ClusterIssuer: $ISSUER_NAME${NC}"

  # Generate ClusterIssuer YAML
  local OUTPUT_FILE="/tmp/clusterissuer-$ISSUER_NAME.yaml"
  sed -e "s|{{ .Email }}|$EMAIL|g" \
      -e "s|{{ .IssuerName }}|$ISSUER_NAME|g" \
      -e "s|{{ .Server }}|$SERVER|g" \
      -e "s|{{ .IngressClass }}|$INGRESS_CLASS|g" \
      "$SCRIPT_DIR/templates/clusterissuer-letsencrypt-prod.yaml.tpl" > "$OUTPUT_FILE"

  echo "OUTPUT_FILE: $OUTPUT_FILE"

  hv_kubectl apply -f "$OUTPUT_FILE"
  echo -e "${GREEN}✅ ClusterIssuer '$ISSUER_NAME' created successfully${NC}"
  #rm -f "$OUTPUT_FILE"
}

function create_certificate() {
  local CERT_NAME=""
  local DOMAIN=""
  local NAMESPACE="ingress-nginx"
  local SECRET_NAME=""
  local ISSUER_NAME="letsencrypt-prod"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --cert-name)
        CERT_NAME="$2"
        shift 2
        ;;
      --domain)
        DOMAIN="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --secret-name)
        SECRET_NAME="$2"
        shift 2
        ;;
      --issuer-name)
        ISSUER_NAME="$2"
        shift 2
        ;;
      *)
        echo -e "${RED}[ERROR] Unknown option: $1${NC}" >&2
        usage
        ;;
    esac
  done

  if [ -z "$CERT_NAME" ]; then
    echo -e "${RED}[ERROR] --cert-name is required${NC}" >&2
    usage
  fi

  if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[ERROR] --domain is required${NC}" >&2
    usage
  fi

  # Default secret name if not provided
  if [ -z "$SECRET_NAME" ]; then
    SECRET_NAME="${CERT_NAME}-secret"
  fi

  echo -e "${GREEN}Creating Certificate: $CERT_NAME${NC}"
  echo -e "${YELLOW}  Domain: $DOMAIN${NC}"
  echo -e "${YELLOW}  Namespace: $NAMESPACE${NC}"
  echo -e "${YELLOW}  Secret: $SECRET_NAME${NC}"
  echo -e "${YELLOW}  Issuer: $ISSUER_NAME${NC}"

  # Generate Certificate YAML
  local OUTPUT_FILE="/tmp/certificate-$CERT_NAME.yaml"
  sed -e "s|{{ .CertName }}|$CERT_NAME|g" \
      -e "s|{{ .Domain }}|$DOMAIN|g" \
      -e "s|{{ .Namespace }}|$NAMESPACE|g" \
      -e "s|{{ .SecretName }}|$SECRET_NAME|g" \
      -e "s|{{ .IssuerName }}|$ISSUER_NAME|g" \
      "$SCRIPT_DIR/templates/certificate.yaml.tpl" > "$OUTPUT_FILE"

  hv_kubectl apply -f "$OUTPUT_FILE"
  echo -e "${GREEN}✅ Certificate '$CERT_NAME' created successfully${NC}"
  rm -f "$OUTPUT_FILE"
}

# Main command dispatcher
if [ "$#" -eq 0 ]; then
  usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
  install-manager)
    install_manager
    ;;
  create-issuer)
    create_issuer "$@"
    ;;
  create-certificate)
    create_certificate "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo -e "${RED}[ERROR] Unknown command: $COMMAND${NC}" >&2
    usage
    ;;
esac
