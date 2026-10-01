#!/bin/bash
set -e

echo "🔄 Restarting NGINX Ingress Controller deployment..."
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=180s

echo "✅ NGINX Ingress Controller deployment restarted successfully."
