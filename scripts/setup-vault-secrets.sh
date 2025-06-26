#!/bin/bash

VAULT_URL="http://34.32.141.92:30090"
VAULT_TOKEN="root"

echo "Setting up Vault secrets for bankapp..."

# Set VAULT_ADDR and VAULT_TOKEN
export VAULT_ADDR=$VAULT_URL
export VAULT_TOKEN=$VAULT_TOKEN

# Enable KV secrets engine if not already enabled
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV secrets engine already enabled"

# Create secrets for dev environment
echo "Creating dev environment secrets..."
vault kv put secret/bankapp/dev/database \
  url="jdbc:mysql://mysql.database.svc.cluster.local:3306/bankappdb_dev?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" \
  username="bankapp_dev" \
  password="dev_password_123"

# Create secrets for prod environment
echo "Creating prod environment secrets..."
vault kv put secret/bankapp/prod/database \
  url="jdbc:mysql://mysql.database.svc.cluster.local:3306/bankappdb_prod?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true" \
  username="bankapp_prod" \
  password="prod_password_456"

# Create secrets for database root password
echo "Creating database root secret..."
vault kv put secret/database/mysql \
  root_password="Test@123"

echo "Vault secrets created successfully!"

# Verify secrets
echo "Verifying secrets..."
vault kv get secret/bankapp/dev/database
vault kv get secret/bankapp/prod/database
vault kv get secret/database/mysql
