# Deployment Scripts

This folder contains deployment and setup scripts for the Bank Application.

## Scripts

### `setup-namespaces.sh`
Creates and configures the required Kubernetes namespaces:
- `dev` - Development environment
- `prod` - Production environment  
- `database` - Shared MySQL database

### `setup-vault-secrets.sh`
Configures Vault with the required secrets for the application:
- Database connection strings for dev and prod
- Database credentials for each environment
- Root password for MySQL

### `deploy-all.sh`
Complete deployment script that:
1. Sets up namespaces
2. Configures Vault secrets
3. Deploys MySQL database
4. Deploys External Secrets configuration
5. Deploys application to dev and prod environments

## Usage

Run the complete deployment:
```bash
cd scripts/
./deploy-all.sh
```

Or run individual scripts:
```bash
./setup-namespaces.sh
./setup-vault-secrets.sh
```

## Prerequisites

- `kubectl` CLI tool
- `vault` CLI tool
- Access to Kubernetes cluster
- Vault server running at http://34.32.141.92:30090
