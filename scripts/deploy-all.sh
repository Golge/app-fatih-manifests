#!/bin/bash

set -e

echo "🚀 Starting bankapp deployment..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "✅ Checking prerequisites..."
if ! command_exists kubectl; then
    echo "❌ kubectl is not installed"
    exit 1
fi

if ! command_exists vault; then
    echo "❌ vault CLI is not installed"
    exit 1
fi

# Setup namespaces
echo "📋 Setting up namespaces..."
./setup-namespaces.sh

# Setup Vault secrets
echo "🔐 Setting up Vault secrets..."
./setup-vault-secrets.sh

# Setup Vault AppRole authentication
echo "🔑 Setting up Vault AppRole authentication..."
./setup-vault-approle.sh

# Deploy database
echo "🗄️ Deploying MySQL database..."
kubectl apply -f ../k8s-manifests/db/

# Wait for database to be ready
echo "⏳ Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql -n database --timeout=300s

# Deploy vault secrets configuration
echo "🔑 Deploying External Secrets configuration..."
kubectl apply -k ../k8s-manifests/vault-secrets/

# Wait a bit for secrets to be created
echo "⏳ Waiting for secrets to be synced..."
sleep 30

# Deploy dev environment
echo "🔧 Deploying to dev environment..."
kubectl apply -k ../k8s-manifests/app/overlays/dev/

# Deploy prod environment
echo "🏭 Deploying to prod environment..."
kubectl apply -k ../k8s-manifests/app/overlays/prod/

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/bankapp -n dev --timeout=300s
kubectl wait --for=condition=available deployment/bankapp -n prod --timeout=300s

echo "🎉 Deployment completed successfully!"

# Show status
echo "📊 Deployment status:"
echo "===================="
kubectl get pods -n dev
echo ""
kubectl get pods -n prod
echo ""
kubectl get pods -n database
echo ""

echo "🌐 Access information:"
echo "====================="
echo "Dev:  http://bankapp-dev.local"
echo "Prod: http://bankapp-prod.local"
echo ""
echo "Make sure to update your /etc/hosts file to point these domains to your ingress controller IP."
