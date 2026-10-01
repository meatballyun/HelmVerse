# NGINX Ingress Controller Management

Generic NGINX Ingress Controller deployment and management tools for Kubernetes. This toolset is project-agnostic and can be used in any Kubernetes cluster.

## Directory Structure

```
nginx/
├── README.md                          # This file
├── deploy-nginx.sh                    # Deploy NGINX Ingress Controller
├── delete-nginx.sh                    # Delete NGINX Ingress Controller
├── restart-nginx-ingress.sh           # Restart NGINX Ingress Controller
├── status-nginx.sh                    # Show NGINX Ingress Controller status
├── create-ingress.sh                  # Create Ingress resources
├── namespace/                         # Namespace configuration
├── serviceaccount/                    # Service account configurations
├── role/                              # Role configurations
├── rolebinding/                       # RoleBinding configurations
├── clusterrole/                       # ClusterRole configurations
├── clusterrolebinding/                # ClusterRoleBinding configurations
├── configmap/                         # ConfigMap for NGINX configuration
├── service/                           # Service configurations
├── deployment/                        # Deployment configuration
├── job/                               # Admission webhook jobs
├── ingressclass/                      # IngressClass configuration
├── validatingwebhookconfiguration/    # Webhook configuration
└── ingress/
    └── templates/
        └── ingress.yaml.tpl           # Ingress template (deprecated, use create-ingress.sh)
```

## Quick Start

### 1. Deploy NGINX Ingress Controller

Deploy the NGINX Ingress Controller to your cluster:

```bash
./deploy-nginx.sh
```

This will:
- Create the `ingress-nginx` namespace
- Deploy all required RBAC resources
- Deploy the NGINX Ingress Controller
- Wait for the deployment to be ready

### 2. Check Status

Verify the deployment:

```bash
./status-nginx.sh
```

### 3. Create an Ingress Resource

Create an Ingress to route traffic to your application:

```bash
# Basic HTTP Ingress
./create-ingress.sh \
  --name myapp \
  --host myapp.example.com \
  --service myapp-svc \
  --port 8080 \
  --apply

# HTTPS Ingress with TLS
./create-ingress.sh \
  --name myapp \
  --host myapp.example.com \
  --service myapp-svc \
  --port 8080 \
  --enable-tls \
  --apply
```

## Usage

### Deploy NGINX Ingress Controller

```bash
./deploy-nginx.sh
```

**What it does:**
- Creates namespace and RBAC resources
- Deploys NGINX Ingress Controller (v1.13.2)
- Configures admission webhooks
- Sets up IngressClass

**Service Type:** NodePort (suitable for local development and Kind clusters)

### Delete NGINX Ingress Controller

```bash
./delete-nginx.sh
```

**Warning:** This will delete all NGINX Ingress Controller resources, but will NOT delete your Ingress resources.

### Restart NGINX Ingress Controller

```bash
./restart-nginx-ingress.sh
```

Performs a rolling restart of the NGINX Ingress Controller deployment.

### Check Status

```bash
./status-nginx.sh
```

Shows:
- Pods in the ingress-nginx namespace
- Services
- Deployments
- IngressClass
- All Ingress resources across all namespaces

### Create Ingress Resources

```bash
./create-ingress.sh [options]
```

**Required Options:**
- `--name <name>`: Name of the Ingress resource
- `--host <host>`: Hostname for the Ingress
- `--service <service>`: Backend service name
- `--port <port>`: Backend service port

**Optional Options:**
- `--namespace <namespace>`: Namespace (default: ingress-nginx)
- `--path <path>`: Path for the Ingress rule (default: /)
- `--path-type <type>`: Path type (default: Prefix)
- `--ingress-class <class>`: Ingress class name (default: nginx)
- `--enable-tls`: Enable TLS/HTTPS
- `--tls-secret <secret>`: TLS secret name (default: <name>-tls-secret)
- `--cluster-issuer <issuer>`: cert-manager ClusterIssuer (default: letsencrypt-prod)
- `--annotations <annot>`: Additional annotations (format: "key1=value1,key2=value2")
- `--output <file>`: Output file path
- `--apply`: Apply the Ingress to the cluster

## Examples

### Example 1: Simple HTTP Application

Deploy an application and create an Ingress:

```bash
# Deploy your application
kubectl create deployment myapp --image=nginx:latest -n default
kubectl expose deployment myapp --port=80 -n default

# Create Ingress
./create-ingress.sh \
  --name myapp-ingress \
  --host myapp.local \
  --service myapp \
  --port 80 \
  --namespace default \
  --apply
```

### Example 2: HTTPS Application with cert-manager

```bash
# Ensure cert-manager is installed and ClusterIssuer is created
# (See ../cert/README.md for cert-manager setup)

# Create HTTPS Ingress
./create-ingress.sh \
  --name secure-app \
  --host secure.example.com \
  --service myapp-svc \
  --port 8080 \
  --namespace production \
  --enable-tls \
  --cluster-issuer letsencrypt-prod \
  --apply
```

### Example 3: API with Path-Based Routing

```bash
# Create Ingress for /api path
./create-ingress.sh \
  --name api-ingress \
  --host api.example.com \
  --service api-svc \
  --port 3000 \
  --path /api \
  --path-type Prefix \
  --namespace default \
  --apply
```

### Example 4: Custom Annotations

```bash
# Create Ingress with custom NGINX annotations
./create-ingress.sh \
  --name webapp \
  --host webapp.example.com \
  --service webapp-svc \
  --port 80 \
  --enable-tls \
  --annotations "nginx.ingress.kubernetes.io/rewrite-target=/,nginx.ingress.kubernetes.io/ssl-redirect=true,nginx.ingress.kubernetes.io/proxy-body-size=10m" \
  --apply
```

### Example 5: Multiple Ingresses for Different Paths

```bash
# Frontend
./create-ingress.sh \
  --name frontend \
  --host myapp.example.com \
  --service frontend-svc \
  --port 3000 \
  --path / \
  --enable-tls \
  --apply

# Backend API
./create-ingress.sh \
  --name backend \
  --host myapp.example.com \
  --service backend-svc \
  --port 8080 \
  --path /api \
  --enable-tls \
  --apply
```

## Configuration

### NGINX Ingress Controller Configuration

The NGINX Ingress Controller is configured via:

1. **ConfigMap** (`configmap/configmap-ingress-nginx-controller.yaml`)
   - Global NGINX configuration
   - Edit this file to customize NGINX behavior

2. **Deployment** (`deployment/deployment-ingress-nginx-controller.yaml`)
   - Controller version: v1.13.2
   - Resource requests: 100m CPU, 90Mi memory
   - Host ports: 80 (HTTP), 443 (HTTPS)

3. **Service** (`service/service-ingress-nginx-controller.yaml`)
   - Type: NodePort
   - Ports: 80 (HTTP), 443 (HTTPS)

### Customizing for Production

For production environments, consider:

1. **Change Service Type to LoadBalancer:**
   ```bash
   # Edit service/service-ingress-nginx-controller.yaml
   # Change: type: NodePort
   # To:     type: LoadBalancer
   ```

2. **Adjust Resource Limits:**
   ```bash
   # Edit deployment/deployment-ingress-nginx-controller.yaml
   # Increase CPU and memory based on your traffic
   ```

3. **Enable Prometheus Metrics:**
   ```bash
   # Add to configmap/configmap-ingress-nginx-controller.yaml
   # enable-prometheus-metrics: "true"
   ```

## Troubleshooting

### Check NGINX Ingress Controller Logs

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f
```

### Check Ingress Events

```bash
kubectl describe ingress <ingress-name> -n <namespace>
```

### Test Ingress Connectivity

```bash
# Get the NodePort
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Test HTTP (replace <node-ip> and <node-port>)
curl -H "Host: myapp.example.com" http://<node-ip>:<node-port>

# For Kind clusters
curl -H "Host: myapp.local" http://localhost
```

### Common Issues

1. **Ingress not routing traffic:**
   - Check that the service and pods exist in the correct namespace
   - Verify the Ingress has an ADDRESS assigned: `kubectl get ingress -A`
   - Check NGINX logs for errors

2. **TLS certificate not working:**
   - Ensure cert-manager is installed
   - Check Certificate status: `kubectl get certificate -A`
   - Verify ClusterIssuer exists: `kubectl get clusterissuer`

3. **404 errors:**
   - Verify the path and pathType in your Ingress
   - Check if the backend service is responding
   - Review NGINX configuration and annotations

4. **502/503 errors:**
   - Check if backend pods are running and healthy
   - Verify service selector matches pod labels
   - Check pod logs for application errors

## Integration with cert-manager

For automatic TLS certificate management:

1. Install cert-manager (see `../cert/README.md`)
2. Create a ClusterIssuer
3. Use `--enable-tls` when creating Ingresses

The NGINX Ingress Controller will automatically:
- Request certificates from cert-manager
- Configure TLS termination
- Renew certificates before expiration

## Notes

- The NGINX Ingress Controller uses NodePort by default (suitable for local development)
- For production, consider using LoadBalancer or cloud provider integrations
- The controller watches all namespaces by default
- IngressClass name is `nginx`
- Version: 1.13.2 (can be updated in deployment YAML)

## Additional Resources

- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Ingress API Reference](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-v1/)
- [cert-manager Integration](https://cert-manager.io/docs/usage/ingress/)
