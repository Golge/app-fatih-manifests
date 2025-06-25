#!/bin/bash

# Validate External Secrets integration with Vault
# This script checks if all secrets are properly synchronized

set -e

echo "🔍 Validating External Secrets integration..."

# Function to check if a secret exists and has data
check_secret() {
    local namespace=$1
    local secret_name=$2
    local expected_keys=$3
    
    echo "Checking secret '$secret_name' in namespace '$namespace'..."
    
    if kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo "  ✅ Secret exists"
        
        # Check if secret has the expected keys
        for key in $expected_keys; do
            if kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" | base64 -d &>/dev/null; then
                echo "  ✅ Key '$key' exists and has data"
            else
                echo "  ❌ Key '$key' missing or empty"
            fi
        done
    else
        echo "  ❌ Secret does not exist"
    fi
    echo ""
}

# Function to check ExternalSecret status
check_external_secret() {
    local namespace=$1
    local es_name=$2
    
    echo "Checking ExternalSecret '$es_name' in namespace '$namespace'..."
    
    if kubectl get externalsecret "$es_name" -n "$namespace" &>/dev/null; then
        local status=$(kubectl get externalsecret "$es_name" -n "$namespace" -o jsonpath='{.status.conditions[0].type}')
        local ready=$(kubectl get externalsecret "$es_name" -n "$namespace" -o jsonpath='{.status.conditions[0].status}')
        
        if [[ "$status" == "Ready" && "$ready" == "True" ]]; then
            echo "  ✅ ExternalSecret is Ready"
        else
            echo "  ❌ ExternalSecret status: $status ($ready)"
            kubectl describe externalsecret "$es_name" -n "$namespace" | tail -5
        fi
    else
        echo "  ❌ ExternalSecret does not exist"
    fi
    echo ""
}

echo "=== Checking SecretStores ==="
kubectl get secretstores -A

echo ""
echo "=== Checking ExternalSecrets ==="
kubectl get externalsecrets -A

echo ""
echo "=== Validating Application Secrets ==="

# Check dev environment
check_external_secret "dev" "db-secret"
check_secret "dev" "db-secret" "url username password"

# Check prod environment  
check_external_secret "prod" "db-secret"
check_secret "prod" "db-secret" "url username password"

# Check database environment
check_external_secret "database" "mysql-root-secret"
check_secret "database" "mysql-root-secret" "password"

echo "=== Checking Vault AppRole Secrets ==="
check_secret "dev" "vault-approle-dev" "role-id secret-id"
check_secret "prod" "vault-approle-prod" "role-id secret-id"
check_secret "database" "vault-approle-database" "role-id secret-id"

echo "=== Summary ==="
echo "If all checks show ✅, your External Secrets integration is working correctly!"
echo "If you see ❌, check the ExternalSecret descriptions for error details:"
echo "  kubectl describe externalsecret <name> -n <namespace>"
