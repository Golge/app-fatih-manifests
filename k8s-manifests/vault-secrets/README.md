# App JavaDes - Vault Integration with External Secrets Operator

This directory contains the configuration for integrating the `app-javdes` application with HashiCorp Vault using the External Secrets Operator (ESO) with AppRole authentication.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │  External       │    │   HashiCorp     │
│   (dev/prod)    │◄──►│  Secrets        │◄──►│   Vault         │
│                 │    │  Operator       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  K8s Secrets    │    │  SecretStore/   │    │   AppRole       │
│  (Injected)     │    │  ExternalSecret │    │  Authentication │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔐 Security Model

### AppRole Authentication
- **Separate AppRoles** for `dev` and `prod` environments
- **Least privilege policies** - each environment can only access its own secrets
- **Short-lived tokens** (1h TTL, 4h max TTL)
- **Role ID stored as Kubernetes secret** in respective namespaces

### Secret Paths in Vault
```
secret/
├── javdes/
│   ├── dev/
│   │   └── database (url, username, password)
│   └── prod/
│       └── database (url, username, password)
└── mysql/
    ├── dev/
    │   └── root (password)
    └── prod/
        └── root (password)
```

## 📁 Files Overview

| File | Purpose |
|------|---------|
| `setup-vault-approle.sh` | Initial Vault configuration script |
| `deploy-external-secrets.sh` | Deployment script for all ESO resources |
| `*-secretstore.yaml` | SecretStore configurations for each namespace |
| `*-external-secret.yaml` | ExternalSecret resources that fetch secrets from Vault |
| `kustomization.yaml` | Kustomize configuration for all ESO resources |

## 🚀 Deployment

### Prerequisites
1. Vault is deployed and accessible at `http://vault.vault.svc.cluster.local:8200`
2. External Secrets Operator is installed in the cluster
3. `vault` CLI is available and configured
4. Namespaces `dev`, `prod`, and `database` exist

### Step 1: Setup Vault AppRole
```bash
cd vault-secrets/
./setup-vault-approle.sh
```

This script will:
- Enable AppRole authentication in Vault
- Create policies for dev/prod environments  
- Create AppRoles with appropriate permissions
- Store secrets in Vault under the correct paths
- Create Kubernetes secrets with AppRole credentials

### Step 2: Deploy External Secrets Configuration
```bash
./deploy-external-secrets.sh
```

Or manually:
```bash
kubectl apply -k .
```

### Step 3: Verify Secret Creation
```bash
# Check ExternalSecret status
kubectl get externalsecrets -A

# Check if secrets were created
kubectl get secrets -n dev | grep db-secret
kubectl get secrets -n prod | grep db-secret
kubectl get secrets -n database | grep mysql-root-secret
```

## 🔧 Environment-Specific Configuration

### Dev Environment
- **Namespace**: `dev`  
- **SecretStore**: `vault-secretstore` (in dev namespace)
- **AppRole**: `javdes-dev`
- **Policy**: `javdes-dev-policy`
- **Secrets**: `secret/javdes/dev/database`

### Prod Environment  
- **Namespace**: `prod`
- **SecretStore**: `vault-secretstore` (in prod namespace)
- **AppRole**: `javdes-prod`
- **Policy**: `javdes-prod-policy`
- **Secrets**: `secret/javdes/prod/database`

## 🔍 Troubleshooting

### Check ExternalSecret Status
```bash
kubectl describe externalsecret db-secret -n dev
kubectl describe externalsecret db-secret -n prod
```

### Check SecretStore Status
```bash
kubectl describe secretstore vault-secretstore -n dev
kubectl describe secretstore vault-secretstore -n prod
```

### Verify Vault Connectivity
```bash
# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200

# Test AppRole authentication
vault write auth/approle/login \
    role_id="<ROLE_ID>" \
    secret_id="<SECRET_ID>"
```

### Check ESO Operator Logs
```bash
kubectl logs -n external-secrets-system deployment/external-secrets
```

## 🔄 Secret Rotation

Secrets are automatically refreshed every **5 minutes** (configured in ExternalSecret resources). To force an immediate refresh:

```bash
kubectl annotate externalsecret db-secret -n dev force-sync=$(date +%s)
kubectl annotate externalsecret db-secret -n prod force-sync=$(date +%s)
```

## 🧹 Cleanup

To remove all External Secrets configuration:
```bash
kubectl delete -k .
```

To clean up Vault configuration (⚠️ **This will delete all secrets**):
```bash
vault auth disable approle
vault policy delete javdes-dev-policy
vault policy delete javdes-prod-policy
vault kv delete secret/javdes/dev/database
vault kv delete secret/javdes/prod/database
```
