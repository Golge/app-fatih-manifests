#!/bin/bash

# Complete deployment script for app-javdes with Vault integration
# This script deploys the entire application stack with secrets from Vault

set -e

echo "🚀 Deploying app-javdes with Vault-managed secrets..."

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if External Secrets Operator is installed
if ! kubectl get crd externalsecrets.external-secrets.io &>/dev/null; then
    echo "❌ External Secrets Operator not found. Please install it first:"
    echo "helm repo add external-secrets https://charts.external-secrets.io"
    echo "helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace"
    exit 1
fi

# Check if Vault is accessible
WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if ! curl -s http://$WORKER_IP:30090/v1/sys/health &>/dev/null; then
    echo "❌ Vault is not accessible at http://$WORKER_IP:30090"
    echo "Please ensure Vault is running and accessible via NodePort 30090"
    exit 1
fi

echo "✅ All prerequisites met"

# Step 1: Setup Vault integration
echo ""
echo "🔐 Step 1: Setting up Vault integration..."
cd vault-secrets/
./deploy-external-secrets.sh

# Wait for secrets to be ready
echo "⏳ Waiting for secrets to be synced..."
sleep 15

# Validate secrets
./validate-secrets.sh

# Step 2: Deploy MySQL
echo ""
echo "🗄️ Step 2: Deploying MySQL..."
cd ../mysql/
kubectl apply -f mysql-namespace-secret.yaml  # Just the namespace, secret comes from Vault
kubectl apply -f mysql-configmap.yaml
kubectl apply -f mysql-statefulset.yaml

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to be ready..."
kubectl wait --for=condition=ready pod -l app=mysql -n database --timeout=300s

# Step 3: Deploy applications
echo ""
echo "📱 Step 3: Deploying applications..."
cd ../app/

# Deploy dev environment
echo "Deploying to dev environment..."
kubectl apply -k overlays/dev/

# Deploy prod environment  
echo "Deploying to prod environment..."
kubectl apply -k overlays/prod/

# Wait for applications to be ready
echo "⏳ Waiting for applications to be ready..."
kubectl wait --for=condition=ready pod -l app=app-javdes -n dev --timeout=300s || echo "Dev pods not ready yet"
kubectl wait --for=condition=ready pod -l app=app-javdes -n prod --timeout=300s || echo "Prod pods not ready yet"

# Step 4: Display status
echo ""
echo "📊 Deployment Status:"
echo ""
echo "=== Vault Secrets ==="
kubectl get externalsecrets -A

echo ""
echo "=== MySQL ==="
kubectl get pods,svc -n database

echo ""
echo "=== Applications ==="
echo "Dev environment:"
kubectl get pods,svc -n dev

echo ""
echo "Prod environment:"
kubectl get pods,svc -n prod

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🌐 Access your applications:"
echo "• Dev:  http://app-javdes-dev.local (add to /etc/hosts)"  
echo "• Prod: http://app-javdes-prod.local (add to /etc/hosts)"
echo ""
echo "🔧 Useful commands:"
echo "• Check secret sync: kubectl describe externalsecret db-secret -n dev"
echo "• View application logs: kubectl logs -f deployment/app-javdes -n dev"
echo "• Connect to MySQL: kubectl exec -it mysql-0 -n database -- mysql -p"
