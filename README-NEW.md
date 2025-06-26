# Bank Application CI/CD Setup

This setup provides a complete CI/CD pipeline for the Bank Application using GitHub Actions, Harbor Registry, Kubernetes, and Vault for secret management.

## Architecture Overview

- **Application Repository**: `app-fatih` - Contains the Java Spring Boot application
- **Manifests Repository**: `app-fatih-manifests` - Contains Kubernetes manifests and deployment configurations
- **Infrastructure**: Kubernetes cluster with Harbor registry, Vault, and External Secrets Operator

## Environments

- **Dev Environment**: Deployed from `dev` branch to `dev` namespace
- **Prod Environment**: Deployed from `main` branch to `prod` namespace
- **Database**: MySQL StatefulSet in `database` namespace (shared between environments)

## Components

### 1. GitHub Actions Pipeline (app-fatih repository)

The CI/CD pipeline consists of three main jobs:

1. **build-and-test**: Runs Maven tests and builds the application
2. **build-and-push-image**: Builds Docker image and pushes to Harbor registry
3. **deploy**: Updates image tags in manifest repository

### 2. Harbor Registry

- **URL**: http://34.32.141.92:30083
- **Project**: javdes
- **Image**: bankapp
- **Credentials**: admin / Harbor12345

### 3. Kubernetes Manifests Structure

```
k8s-manifests/
├── app/
│   ├── base/                    # Base application manifests
│   └── overlays/
│       ├── dev/                 # Dev environment specific configs
│       └── prod/                # Prod environment specific configs
├── db/                          # MySQL database manifests
└── vault-secrets/               # External secrets configurations
scripts/                         # Deployment and setup scripts
├── setup-namespaces.sh          # Create namespaces
├── setup-vault-secrets.sh       # Configure Vault secrets
└── deploy-all.sh                # Complete deployment script
```

### 4. Vault Secret Management

Secrets are stored in Vault and fetched using External Secrets Operator with AppRole authentication:

- **Dev secrets**: `secret/bankapp/dev/database`
- **Prod secrets**: `secret/bankapp/prod/database`
- **Database secrets**: `secret/database/mysql`

### 5. Database Configuration

MySQL StatefulSet with:
- **Dev Database**: `bankappdb_dev` with user `bankapp_dev`
- **Prod Database**: `bankappdb_prod` with user `bankapp_prod`
- **Persistent storage**: 20Gi NFS storage

## Deployment Instructions

### Prerequisites

1. Kubernetes cluster with:
   - Harbor registry running
   - Vault server running
   - External Secrets Operator installed
   - NGINX Ingress Controller
   - NFS storage class

2. Required CLI tools:
   - `kubectl`
   - `vault`

### Initial Setup

1. **Setup namespaces**:
   ```bash
   cd scripts
   ./setup-namespaces.sh
   ```

2. **Configure Vault secrets**:
   ```bash
   ./setup-vault-secrets.sh
   ```

3. **Deploy everything**:
   ```bash
   ./deploy-all.sh
   ```

### Manual Deployment Steps

If you prefer manual deployment:

1. **Deploy database**:
   ```bash
   kubectl apply -f db/
   ```

2. **Deploy External Secrets configuration**:
   ```bash
   kubectl apply -f vault-secrets/
   ```

3. **Deploy to dev environment**:
   ```bash
   kubectl apply -k app/overlays/dev/
   ```

4. **Deploy to prod environment**:
   ```bash
   kubectl apply -k app/overlays/prod/
   ```

## Access Information

### Application URLs

- **Dev**: http://bankapp-dev.local
- **Prod**: http://bankapp-prod.local

> **Note**: Add these entries to your `/etc/hosts` file pointing to your ingress controller IP.

### Harbor Registry

- **URL**: http://34.32.141.92:30083
- **Login**: `docker login 34.32.141.92:30083 -u admin -p Harbor12345`

### Vault

- **URL**: http://34.32.141.92:30090
- **Root Token**: `root`

## Database Connections

The application connects to MySQL with environment-specific configurations:

### Dev Environment
- **URL**: `jdbc:mysql://mysql.database.svc.cluster.local:3306/bankappdb_dev`
- **Username**: `bankapp_dev`
- **Password**: `dev_password_123`

### Prod Environment
- **URL**: `jdbc:mysql://mysql.database.svc.cluster.local:3306/bankappdb_prod`
- **Username**: `bankapp_prod`
- **Password**: `prod_password_456`

## Secret Management

Secrets are managed through Vault and synchronized to Kubernetes using External Secrets Operator:

1. Secrets are stored in Vault under:
   - `secret/bankapp/dev/database`
   - `secret/bankapp/prod/database`

2. External Secrets creates Kubernetes secrets in respective namespaces

3. Application pods consume secrets through environment variables

## Monitoring and Troubleshooting

### Check deployment status:
```bash
kubectl get pods -n dev
kubectl get pods -n prod
kubectl get pods -n database
```

### Check secrets:
```bash
kubectl get secrets -n dev
kubectl get secrets -n prod
kubectl get externalsecrets -n dev
kubectl get externalsecrets -n prod
```

### Check external secrets logs:
```bash
kubectl logs -n external-secrets-system deployment/external-secrets
```

### Verify Vault connectivity:
```bash
vault status
vault kv get secret/bankapp/dev/database
```

## CI/CD Workflow

1. **Developer pushes to dev branch**:
   - GitHub Actions builds and tests the application
   - Creates Docker image with `dev-<commit-hash>` tag
   - Pushes to Harbor registry
   - Updates image tag in manifest repository dev overlay

2. **Developer pushes to main branch**:
   - GitHub Actions builds and tests the application
   - Creates Docker image with `prod-<commit-hash>` tag
   - Pushes to Harbor registry
   - Updates image tag in manifest repository prod overlay

3. **Deployment to Kubernetes**:
   - Manual deployment using `kubectl apply` or GitOps tool
   - Alternatively, can be automated with ArgoCD (not included in current setup)

## Security Notes

- Database passwords are stored in Vault and rotated as needed
- Harbor registry uses basic authentication (consider implementing token-based auth for production)
- External Secrets Operator uses AppRole authentication with Vault
- Network policies should be implemented for production deployments

## Scaling Considerations

- **Dev**: 1 replica (resource-efficient for development)
- **Prod**: 3 replicas (high availability)
- **Database**: Single MySQL instance with persistent storage
- Consider implementing read replicas for production workloads
