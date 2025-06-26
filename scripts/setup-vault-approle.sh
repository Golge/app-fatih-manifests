#!/bin/bash

VAULT_URL="http://34.32.141.92:30090"
VAULT_TOKEN="root"

echo "Setting up Vault AppRole authentication for bankapp..."

# Set VAULT_ADDR and VAULT_TOKEN
export VAULT_ADDR=$VAULT_URL
export VAULT_TOKEN=$VAULT_TOKEN

# Enable AppRole auth method if not already enabled
echo "Enabling AppRole authentication method..."
vault auth enable approle 2>/dev/null || echo "AppRole auth method already enabled"

# Create policy for dev environment
echo "Creating dev policy..."
vault policy write bankapp-dev - <<EOF
path "secret/data/bankapp/dev/*" {
  capabilities = ["read"]
}
EOF

# Create policy for prod environment
echo "Creating prod policy..."
vault policy write bankapp-prod - <<EOF
path "secret/data/bankapp/prod/*" {
  capabilities = ["read"]
}
EOF

# Create AppRole for dev environment
echo "Creating dev AppRole..."
vault write auth/approle/role/bankapp-dev \
    token_policies="bankapp-dev" \
    token_ttl=1h \
    token_max_ttl=4h

# Create AppRole for prod environment
echo "Creating prod AppRole..."
vault write auth/approle/role/bankapp-prod \
    token_policies="bankapp-prod" \
    token_ttl=1h \
    token_max_ttl=4h

# Get role IDs
echo "Getting role IDs..."
DEV_ROLE_ID=$(vault read -field=role_id auth/approle/role/bankapp-dev/role-id)
PROD_ROLE_ID=$(vault read -field=role_id auth/approle/role/bankapp-prod/role-id)

# Generate secret IDs
echo "Generating secret IDs..."
DEV_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/bankapp-dev/secret-id)
PROD_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/bankapp-prod/secret-id)

echo "AppRole setup completed!"
echo "=========================="
echo "Dev Role ID: $DEV_ROLE_ID"
echo "Dev Secret ID: $DEV_SECRET_ID"
echo "Prod Role ID: $PROD_ROLE_ID"
echo "Prod Secret ID: $PROD_SECRET_ID"
echo "=========================="

# Update the Kubernetes secrets with actual role and secret IDs
echo "Updating Kubernetes AppRole secrets..."

# Update dev AppRole secret
kubectl patch secret vault-approle-dev -n dev --type='json' -p='[
  {"op": "replace", "path": "/data/role-id", "value": "'$(echo -n $DEV_ROLE_ID | base64)'"},
  {"op": "replace", "path": "/data/secret-id", "value": "'$(echo -n $DEV_SECRET_ID | base64)'"}
]' 2>/dev/null || echo "Dev secret will be created during deployment"

# Update prod AppRole secret
kubectl patch secret vault-approle-prod -n prod --type='json' -p='[
  {"op": "replace", "path": "/data/role-id", "value": "'$(echo -n $PROD_ROLE_ID | base64)'"},
  {"op": "replace", "path": "/data/secret-id", "value": "'$(echo -n $PROD_SECRET_ID | base64)'"}
]' 2>/dev/null || echo "Prod secret will be created during deployment"

echo "✅ Vault AppRole authentication setup completed!"
