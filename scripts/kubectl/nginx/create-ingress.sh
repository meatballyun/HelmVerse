#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory of the current script
SCRIPT_DIR="$(dirname "$0")"

function usage() {
  cat <<EOF
Usage: $0 [options]

Create a Kubernetes Ingress resource with customizable options.

Required Options:
  --name <name>              Name of the Ingress resource
  --host <host>              Hostname for the Ingress (e.g., myapp.example.com)
  --service <service>        Backend service name
  --port <port>              Backend service port

Optional Options:
  --namespace <namespace>    Namespace for the Ingress (default: ingress-nginx)
  --path <path>              Path for the Ingress rule (default: /)
  --path-type <type>         Path type: Prefix, Exact, or ImplementationSpecific (default: Prefix)
  --ingress-class <class>    Ingress class name (default: nginx)
  --enable-tls               Enable TLS/HTTPS
  --tls-secret <secret>      TLS secret name (default: <name>-tls-secret)
  --cluster-issuer <issuer>  cert-manager ClusterIssuer name (default: letsencrypt-prod)
  --annotations <annot>      Additional annotations (format: "key1=value1,key2=value2")
  --output <file>            Output file path (default: /tmp/ingress-<name>.yaml)
  --apply                    Apply the Ingress to the cluster after generation

Examples:
  # Basic HTTP Ingress
  $0 --name myapp --host myapp.example.com --service myapp-svc --port 8080

  # HTTPS Ingress with TLS
  $0 --name myapp --host myapp.example.com --service myapp-svc --port 8080 \\
    --enable-tls --apply

  # Custom namespace and path
  $0 --name api --host api.example.com --service api-svc --port 3000 \\
    --namespace production --path /api --path-type Prefix --apply

  # With custom annotations
  $0 --name webapp --host webapp.example.com --service webapp-svc --port 80 \\
    --enable-tls --annotations "nginx.ingress.kubernetes.io/rewrite-target=/,nginx.ingress.kubernetes.io/ssl-redirect=true"

EOF
  exit 1
}

# Default values
NAMESPACE="ingress-nginx"
PATH_RULE="/"
PATH_TYPE="Prefix"
INGRESS_CLASS="nginx"
ENABLE_TLS=false
TLS_SECRET=""
CLUSTER_ISSUER="letsencrypt-prod"
ANNOTATIONS=""
OUTPUT_FILE=""
APPLY=false

# Required parameters
INGRESS_NAME=""
HOST=""
SERVICE_NAME=""
SERVICE_PORT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      INGRESS_NAME="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --service)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --port)
      SERVICE_PORT="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --path)
      PATH_RULE="$2"
      shift 2
      ;;
    --path-type)
      PATH_TYPE="$2"
      shift 2
      ;;
    --ingress-class)
      INGRESS_CLASS="$2"
      shift 2
      ;;
    --enable-tls)
      ENABLE_TLS=true
      shift
      ;;
    --tls-secret)
      TLS_SECRET="$2"
      shift 2
      ;;
    --cluster-issuer)
      CLUSTER_ISSUER="$2"
      shift 2
      ;;
    --annotations)
      ANNOTATIONS="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --apply)
      APPLY=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo -e "${RED}[ERROR] Unknown option: $1${NC}" >&2
      usage
      ;;
  esac
done

# Validate required parameters
if [ -z "$INGRESS_NAME" ]; then
  echo -e "${RED}[ERROR] --name is required${NC}" >&2
  usage
fi

if [ -z "$HOST" ]; then
  echo -e "${RED}[ERROR] --host is required${NC}" >&2
  usage
fi

if [ -z "$SERVICE_NAME" ]; then
  echo -e "${RED}[ERROR] --service is required${NC}" >&2
  usage
fi

if [ -z "$SERVICE_PORT" ]; then
  echo -e "${RED}[ERROR] --port is required${NC}" >&2
  usage
fi

# Set default TLS secret name if not provided
if [ "$ENABLE_TLS" = true ] && [ -z "$TLS_SECRET" ]; then
  TLS_SECRET="${INGRESS_NAME}-tls-secret"
fi

# Set default output file if not provided
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="/tmp/ingress-${INGRESS_NAME}.yaml"
fi

# Process annotations
ANNOTATION_LINES=""
if [ -n "$ANNOTATIONS" ]; then
  IFS=',' read -ra ANNOT_ARRAY <<< "$ANNOTATIONS"
  for annot in "${ANNOT_ARRAY[@]}"; do
    KEY="${annot%%=*}"
    VALUE="${annot#*=}"
    ANNOTATION_LINES="${ANNOTATION_LINES}    ${KEY}: \"${VALUE}\"\n"
  done
fi

echo -e "${GREEN}Creating Ingress: $INGRESS_NAME${NC}"
echo -e "${YELLOW}  Host: $HOST${NC}"
echo -e "${YELLOW}  Service: $SERVICE_NAME:$SERVICE_PORT${NC}"
echo -e "${YELLOW}  Namespace: $NAMESPACE${NC}"
echo -e "${YELLOW}  Path: $PATH_RULE ($PATH_TYPE)${NC}"
echo -e "${YELLOW}  Ingress Class: $INGRESS_CLASS${NC}"
if [ "$ENABLE_TLS" = true ]; then
  echo -e "${YELLOW}  TLS: Enabled (Secret: $TLS_SECRET, Issuer: $CLUSTER_ISSUER)${NC}"
else
  echo -e "${YELLOW}  TLS: Disabled${NC}"
fi

# Generate Ingress YAML
cat > "$OUTPUT_FILE" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${INGRESS_NAME}
  namespace: ${NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
$(echo -e "$ANNOTATION_LINES")
spec:
  ingressClassName: ${INGRESS_CLASS}
EOF

# Add TLS section if enabled
if [ "$ENABLE_TLS" = true ]; then
  cat >> "$OUTPUT_FILE" <<EOF
  tls:
    - hosts:
        - ${HOST}
      secretName: ${TLS_SECRET}
EOF
fi

# Add rules section
cat >> "$OUTPUT_FILE" <<EOF
  rules:
    - host: ${HOST}
      http:
        paths:
          - path: ${PATH_RULE}
            pathType: ${PATH_TYPE}
            backend:
              service:
                name: ${SERVICE_NAME}
                port:
                  number: ${SERVICE_PORT}
EOF

echo -e "${GREEN}✅ Ingress YAML generated: $OUTPUT_FILE${NC}"

# Apply if requested
if [ "$APPLY" = true ]; then
  echo -e "${GREEN}Applying Ingress to cluster...${NC}"
  kubectl apply -f "$OUTPUT_FILE"
  echo -e "${GREEN}✅ Ingress '$INGRESS_NAME' applied successfully${NC}"

  # Show status
  echo -e "\n${YELLOW}Ingress Status:${NC}"
  kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE"

  if [ "$ENABLE_TLS" = true ]; then
    echo -e "\n${YELLOW}Certificate Status (if using cert-manager):${NC}"
    kubectl get certificate -n "$NAMESPACE" 2>/dev/null || echo "No certificates found (cert-manager may not be installed)"
  fi
else
  echo -e "${YELLOW}To apply this Ingress, run:${NC}"
  echo -e "  kubectl apply -f $OUTPUT_FILE"
fi
