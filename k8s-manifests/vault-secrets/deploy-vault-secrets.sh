#!/bin/bash

# Setup script for Vault External Secrets with AppRole authentication
# This script helps configure the necessary components for using External Secrets with Vault

set -e

echo "🚀 Setting up Vault External Secrets with AppRole authentication"
echo "=============================================================="

# Create namespaces if they don't exist
echo "📂 Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# Apply AppRole secrets 
echo "🔐 Applying AppRole secrets..."
kubectl apply -f vault-approle-database-secret.yaml
kubectl apply -f vault-approle-dev-secret.yaml
kubectl apply -f vault-approle-prod-secret.yaml

# Deploy the Secret Stores
echo "📂 Deploying Secret Stores..."
kubectl apply -f dev-secretstore.yaml
kubectl apply -f prod-secretstore.yaml
kubectl apply -f database-secretstore.yaml

# Deploy External Secrets for MySQL
echo "🔑 Deploying MySQL External Secrets..."
kubectl apply -f dev-mysql-external-secret.yaml
kubectl apply -f prod-mysql-external-secret.yaml

# Deploy Application External Secrets
echo "🔑 Deploying Application External Secrets..."
kubectl apply -f dev-app-external-secret.yaml
kubectl apply -f prod-app-external-secret.yaml

echo
echo "✅ Deployment complete!"
echo
echo "To verify the status of your External Secrets:"
echo "kubectl get externalsecrets -A"
echo
echo "To validate if secrets are being created properly:"
echo "./validate-secrets.sh"
