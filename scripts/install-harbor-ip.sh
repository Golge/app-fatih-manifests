#!/bin/bash

# Harbor Installation with IP-based configuration
# This script installs Harbor registry using Helm with external IP access

set -e

echo "🐳 Installing Harbor Registry with IP-based configuration..."

# Get the external IP of the first worker node
WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$WORKER_IP" ]; then
    echo "⚠️  External IP not found, trying InternalIP..."
    WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

# Check if PUBLIC_IP is provided as environment variable for public clusters
if [ -n "$PUBLIC_IP" ]; then
    echo "🌐 Using provided PUBLIC_IP: $PUBLIC_IP"
    EXTERNAL_IP="$PUBLIC_IP"
    INTERNAL_IP="$WORKER_IP"
else
    EXTERNAL_IP="$WORKER_IP"
    INTERNAL_IP="$WORKER_IP"
fi

if [ -z "$WORKER_IP" ]; then
    echo "❌ Could not determine worker node IP. Please set PUBLIC_IP manually."
    echo "Usage: PUBLIC_IP=34.32.141.92 ./install-harbor-ip.sh"
    exit 1
fi

echo "🔍 Using Internal IP: $INTERNAL_IP"
echo "🌐 Using External IP: $EXTERNAL_IP"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Please install Helm first."
    exit 1
fi

# Add Harbor Helm repository
echo "📚 Adding Harbor Helm repository..."
helm repo add harbor https://helm.goharbor.io
helm repo update

# Create namespace for Harbor
echo "🏗️ Creating harbor namespace..."
kubectl create namespace harbor || echo "Namespace already exists"

# Create Harbor values file with IP-based configuration
echo "📝 Creating Harbor configuration for External IP: $EXTERNAL_IP..."
cat > /tmp/harbor-values-ip.yaml <<EOF
expose:
  type: nodePort
  nodePort:
    name: harbor
    ports:
      http:
        port: 80
        nodePort: 30083
      https:
        port: 443
        nodePort: 30084
  ingress:
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    hosts:
      core: $EXTERNAL_IP
      notary: notary.$EXTERNAL_IP
  tls:
    enabled: false

# Use external IP address for external URL
externalURL: http://$EXTERNAL_IP:30083

# Persistence settings
persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      size: 50Gi
    chartmuseum:
      size: 5Gi
    jobservice:
      size: 1Gi
    database:
      size: 1Gi
    redis:
      size: 1Gi
    trivy:
      size: 5Gi

# Harbor admin password
harborAdminPassword: "Harbor12345"

# Database settings
database:
  type: internal

# Redis settings
redis:
  type: internal

# Chartmuseum for Helm charts
chartmuseum:
  enabled: true

# Trivy for vulnerability scanning
trivy:
  enabled: true

# Notary for content trust
notary:
  enabled: false  # Disable notary to avoid complications

# Core service
core:
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m

# Registry service
registry:
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m

# Portal (Web UI)
portal:
  resources:
    requests:
      memory: 128Mi
      cpu: 50m
    limits:
      memory: 512Mi
      cpu: 250m

# Job service
jobservice:
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m
EOF

# Uninstall existing Harbor if it exists
if helm list -n harbor | grep -q harbor; then
    echo "🔄 Harbor already installed. Performing clean reinstall..."
    echo "Uninstalling existing Harbor..."
    helm uninstall harbor -n harbor
    echo "Waiting for Harbor resources to be cleaned up..."
    sleep 30
    echo "Deleting PVCs..."
    kubectl delete pvc --all -n harbor || true
    sleep 10
fi

echo "Installing Harbor with IP-based configuration..."
helm install harbor harbor/harbor \
    --namespace harbor \
    --values /tmp/harbor-values-ip.yaml \
    --timeout 15m

# Wait for Harbor to be ready
echo "⏳ Waiting for Harbor to be ready..."
kubectl wait --for=condition=ready pod -l app=harbor-core -n harbor --timeout=800s || {
    echo "⚠️  Timeout waiting for Harbor core. Checking status..."
    kubectl get pods -n harbor
}

# Check Harbor pod status
echo "🔍 Checking Harbor pod status..."
kubectl get pods -n harbor

echo "✅ Harbor installation completed!"
echo ""
echo "📋 Harbor Details:"
echo "• Namespace: harbor"
echo "• Internal URL: http://$INTERNAL_IP:30083"
echo "• External URL: http://$EXTERNAL_IP:30083"
echo "• Admin Username: admin"
echo "• Admin Password: Harbor12345"
echo ""
echo "🐳 Docker login command (internal):"
echo "docker login $INTERNAL_IP:30083 -u admin -p Harbor12345"
echo ""
echo "🐳 Docker login command (external):"
echo "docker login $EXTERNAL_IP:30083 -u admin -p Harbor12345"
echo ""
echo "🔧 To configure Docker for insecure registry:"
echo "echo '{\"insecure-registries\":[\"$EXTERNAL_IP:30083\",\"$INTERNAL_IP:30083\"]}' | sudo tee /etc/docker/daemon.json"
echo "sudo systemctl restart docker"

# Clean up
rm -f /tmp/harbor-values-ip.yaml

echo ""
echo "🌐 Access Harbor web UI at: http://$EXTERNAL_IP:30083"
echo ""
echo "📝 For GitHub Actions, use: $EXTERNAL_IP:30083"
