#!/bin/bash

# Deploy External Secrets and Vault integration
# This script deploys the External Secrets Operator configuration for the app-javdes project

set -e

echo "🔐 Deploying External Secrets configuration for app-javdes..."

# Check if External Secrets Operator is installed
if ! kubectl get crd externalsecrets.external-secrets.io &>/dev/null; then
    echo "❌ External Secrets Operator not found. Please install it first:"
    echo "helm repo add external-secrets https://charts.external-secrets.io"
    echo "helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace"
    exit 1
fi

# Check if Vault AppRole setup has been run
echo "🔍 Checking if Vault AppRole credentials exist..."
if ! kubectl get secret vault-approle-dev -n dev &>/dev/null; then
    echo "⚠️  Vault AppRole credentials not found. Running setup..."
    chmod +x setup-vault-approle.sh
    ./setup-vault-approle.sh
else
    echo "✅ Vault AppRole credentials found"
fi

# Ensure namespaces exist
echo "📁 Creating namespaces if they don't exist..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# Apply External Secrets configuration
echo "📋 Applying External Secrets manifests..."

# Apply SecretStores
kubectl apply -f dev-secretstore.yaml
kubectl apply -f prod-secretstore.yaml
kubectl apply -f database-secretstore.yaml

# Apply ExternalSecrets
kubectl apply -f dev-app-external-secret.yaml
kubectl apply -f prod-app-external-secret.yaml
kubectl apply -f dev-mysql-external-secret.yaml
kubectl apply -f prod-mysql-external-secret.yaml

# Wait for secrets to be created
echo "⏳ Waiting for secrets to be created by External Secrets Operator..."
sleep 10

# Check if secrets were created successfully
echo "🔍 Checking created secrets..."

echo "Secrets in dev namespace:"
kubectl get secrets -n dev | grep -E "(db-secret|vault-approle)" || echo "No secrets found in dev namespace"

echo "Secrets in prod namespace:"
kubectl get secrets -n prod | grep -E "(db-secret|vault-approle)" || echo "No secrets found in prod namespace"

echo "Secrets in database namespace:"
kubectl get secrets -n database | grep -E "(mysql-root-secret|vault-approle)" || echo "No secrets found in database namespace"

# Check ExternalSecret status
echo "📊 ExternalSecret status:"
kubectl get externalsecrets -n dev
kubectl get externalsecrets -n prod
kubectl get externalsecrets -n database

echo "✅ External Secrets configuration deployed!"
echo ""
echo "📝 Next steps:"
echo "1. Deploy your application: kubectl apply -k ../app/overlays/dev/"
echo "2. Deploy MySQL: kubectl apply -f ../mysql/"
echo "3. Check that secrets are properly injected into pods"
