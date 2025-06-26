#!/bin/bash

# Setup Infrastructure for BankApp
# This script sets up cert-manager, certificates, and other infrastructure components

set -e

echo "🚀 Setting up Infrastructure for BankApp..."

# Function to check if a namespace exists
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Function to wait for cert-manager to be ready
wait_for_cert_manager() {
    echo "⏳ Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    echo "✅ cert-manager is ready"
}

# Check if cert-manager namespace exists
if ! namespace_exists "cert-manager"; then
    echo "❌ cert-manager namespace not found. Please install cert-manager first."
    echo "Run: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml"
    exit 1
fi

# Wait for cert-manager to be ready
wait_for_cert_manager

# Apply ClusterIssuers
echo "🔑 Creating ClusterIssuers..."
kubectl apply -f k8s-manifests/infrastructure/cert-manager/selfsigned-cluster-issuer.yaml

# Wait a bit for the ClusterIssuer to be ready
echo "⏳ Waiting for ClusterIssuers to be ready..."
sleep 10

# Check ClusterIssuer status
echo "📋 Checking ClusterIssuer status..."
kubectl get clusterissuer

# Apply certificates
echo "📜 Creating certificates..."
kubectl apply -f k8s-manifests/infrastructure/certificates/bankapp-certificates.yaml

# Wait for certificates to be issued
echo "⏳ Waiting for certificates to be ready..."
sleep 15

# Check certificate status
echo "📋 Checking certificate status..."
kubectl get certificates -n dev
kubectl get certificates -n prod

# Check if certificates are ready
echo "🔍 Certificate details:"
kubectl describe certificate bankapp-dev-tls -n dev
kubectl describe certificate bankapp-prod-tls -n prod

echo "✅ Infrastructure setup complete!"
echo ""
echo "🔗 Next steps:"
echo "  1. Apply your application manifests"
echo "  2. Update ingress to use the new certificates"
echo "  3. Access your applications via HTTPS"
