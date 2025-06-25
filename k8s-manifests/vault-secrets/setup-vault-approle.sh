#!/bin/bash

# Vault AppRole Setup for External Secrets Operator
# This script configures Vault with AppRole authentication for dev and prod environments

set -e

echo "🔐 Setting up Vault AppRole for External Secrets Operator..."
echo "============================================"
echo "This script will:"
echo "1. Create policies for dev and prod environments"
echo "2. Set up AppRole authentication"
echo "3. Generate role-id and secret-id credentials"
echo "4. Store sample secrets in Vault"
echo "5. Create Kubernetes secrets for AppRole credentials"
echo "============================================"
echo ""
echo "⚠️  Prerequisites:"
echo "- Vault server should be running and unsealed"
echo "- You need a valid token with permissions to:"
echo "  • Create policies"
echo "  • Enable auth methods"
echo "  • Write secrets"
echo ""
echo "If you don't have a token, you might need to:"
echo "1. Initialize Vault: vault operator init"
echo "2. Unseal Vault: vault operator unseal"
echo "3. Login with the root token from initialization"
echo ""

# Get worker node external IP for NodePort access
WORKER_NODE_IP='34.147.56.126'
if [ -z "$WORKER_NODE_IP" ]; then
    WORKER_NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
fi

# Export Vault address (using NodePort 30090)
export VAULT_ADDR="http://${WORKER_NODE_IP}:30090"
echo "Vault address: $VAULT_ADDR"

# Check if Vault is initialized and unsealed
echo "Checking Vault status..."
vault status || echo "Vault might not be ready yet..."

# Login to Vault
echo "Please enter your Vault token to authenticate:"
read -s VAULT_TOKEN
export VAULT_TOKEN
vault token lookup > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Authentication failed. Please check your token."
    exit 1
else
    echo "✅ Successfully authenticated with Vault."
fi

# Enable AppRole auth method
echo "Enabling AppRole auth method..."
vault auth enable approle 2>/dev/null || echo "AppRole already enabled"

# Create policies for dev and prod environments
echo "Creating Vault policies..."

# Dev environment policy
vault policy write javdes-dev-policy - <<EOF
# Policy for dev environment secrets
path "secret/data/javdes/dev/*" {
  capabilities = ["read"]
}
path "secret/data/mysql/dev/*" {
  capabilities = ["read"]
}
path "secret/data/dev/*" {
  capabilities = ["read"]
}
EOF

# Prod environment policy  
vault policy write javdes-prod-policy - <<EOF
# Policy for prod environment secrets
path "secret/data/javdes/prod/*" {
  capabilities = ["read"]
}
path "secret/data/mysql/prod/*" {
  capabilities = ["read"]
}
path "secret/data/prod/*" {
  capabilities = ["read"]
}
EOF

# Database namespace policy (uses dev credentials but needs access to both dev and prod MySQL secrets)
vault policy write javdes-database-policy - <<EOF
# Policy for database namespace secrets
path "secret/data/mysql/dev/*" {
  capabilities = ["read"]
}
path "secret/data/mysql/prod/*" {
  capabilities = ["read"]
}  
path "secret/data/dev/*" {
  capabilities = ["read"]
}
path "secret/data/prod/*" {
  capabilities = ["read"]
}
EOF

# Create AppRoles for dev and prod
echo "Creating AppRoles..."

# Dev AppRole
vault write auth/approle/role/javdes-dev \
    token_policies="javdes-dev-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    bind_secret_id=true

# Prod AppRole
vault write auth/approle/role/javdes-prod \
    token_policies="javdes-prod-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    bind_secret_id=true

# Database AppRole (for database namespace)
vault write auth/approle/role/javdes-database \
    token_policies="javdes-database-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    bind_secret_id=true

# Get RoleIDs and SecretIDs
echo "Getting AppRole credentials..."

DEV_ROLE_ID=$(vault read -field=role_id auth/approle/role/javdes-dev/role-id)
DEV_SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/javdes-dev/secret-id)

PROD_ROLE_ID=$(vault read -field=role_id auth/approle/role/javdes-prod/role-id)
PROD_SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/javdes-prod/secret-id)

DATABASE_ROLE_ID=$(vault read -field=role_id auth/approle/role/javdes-database/role-id)
DATABASE_SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/javdes-database/secret-id)

echo "Dev Role ID: $DEV_ROLE_ID"
echo "Dev Secret ID: $DEV_SECRET_ID"
echo "Prod Role ID: $PROD_ROLE_ID"
echo "Prod Secret ID: $PROD_SECRET_ID"
echo "Database Role ID: $DATABASE_ROLE_ID"
echo "Database Secret ID: $DATABASE_SECRET_ID"

# Store the secrets in Vault
echo "Storing application secrets in Vault..."

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV v2 already enabled"

# Dev environment secrets
vault kv put secret/javdes/dev/database \
    url="jdbc:mysql://mysql.database.svc.cluster.local:3306/javdes_dev" \
    username="javdes_user" \
    password="dev_password_123"

vault kv put secret/mysql/dev/root \
    password="dev_root_password_123"

# Add secrets matching the UI structure
vault kv put secret/dev/MYSQL_ROOT_PASSWORD \
    password="dev_root_password_123"

# Prod environment secrets  
vault kv put secret/javdes/prod/database \
    url="jdbc:mysql://mysql.database.svc.cluster.local:3306/javdes_prod" \
    username="javdes_user" \
    password="prod_password_456"

vault kv put secret/mysql/prod/root \
    password="prod_root_password_456"

# Add secrets matching the UI structure
vault kv put secret/prod/MYSQL_ROOT_PASSWORD \
    password="prod_root_password_456"

# Create Kubernetes secrets for AppRole credentials
echo "Creating Kubernetes secrets for AppRole credentials..."

# Create namespaces
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# Create AppRole secrets for External Secrets Operator
kubectl create secret generic vault-approle-dev \
    --from-literal=role-id="$DEV_ROLE_ID" \
    --from-literal=secret-id="$DEV_SECRET_ID" \
    --namespace=dev \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic vault-approle-prod \
    --from-literal=role-id="$PROD_ROLE_ID" \
    --from-literal=secret-id="$PROD_SECRET_ID" \
    --namespace=prod \
    --dry-run=client -o yaml | kubectl apply -f -

# Create database namespace secret with database-specific credentials
kubectl create secret generic vault-approle-database \
    --from-literal=role-id="$DATABASE_ROLE_ID" \
    --from-literal=secret-id="$DATABASE_SECRET_ID" \
    --namespace=database \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Vault AppRole setup completed!"
echo ""
echo "📋 Summary:"
echo "• Created policies: javdes-dev-policy, javdes-prod-policy, javdes-database-policy"
echo "• Created AppRoles: javdes-dev, javdes-prod, javdes-database"
echo "• Stored secrets in Vault under secret/javdes/{dev,prod}/, secret/mysql/{dev,prod}/, and secret/{dev,prod}/"
echo "• Created Kubernetes secrets: vault-approle-dev, vault-approle-prod, vault-approle-database"
echo ""
echo "🔑 AppRole Credentials:"
echo "Dev Environment:"
echo "  Role ID: $DEV_ROLE_ID"
echo "  Secret ID: $DEV_SECRET_ID"
echo ""
echo "Prod Environment:"
echo "  Role ID: $PROD_ROLE_ID"  
echo "  Secret ID: $PROD_SECRET_ID"
echo ""
echo "Database Environment:"
echo "  Role ID: $DATABASE_ROLE_ID"  
echo "  Secret ID: $DATABASE_SECRET_ID"
