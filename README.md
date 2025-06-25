# App JavaDes - Kubernetes Manifests

This repository contains Kubernetes manifests for the JavaDes application with integrated secrets management using HashiCorp Vault and External Secrets Operator.

## 🏗️ Architecture

- **Application**: Spring Boot application deployed in dev/prod environments
- **Database**: MySQL StatefulSet with persistent storage
- **Secrets Management**: HashiCorp Vault with External Secrets Operator
- **Authentication**: AppRole-based authentication for secure secret access
- **Configuration**: Kustomize for environment-specific configurations

## 📁 Project Structure

```
k8s-manifests/
├── app/                          # Application manifests
│   ├── base/                     # Base Kustomize configuration
│   │   ├── deployment.yaml       # App deployment
│   │   ├── service.yaml          # App service
│   │   ├── ingress.yaml          # App ingress
│   │   └── kustomization.yaml    # Base kustomization
│   └── overlays/                 # Environment-specific overlays
│       ├── dev/                  # Development environment
│       │   ├── deployment-patch.yaml
│       │   └── kustomization.yaml
│       └── prod/                 # Production environment
│           ├── deployment-patch.yaml
│           └── kustomization.yaml
├── mysql/                        # MySQL database manifests
│   ├── mysql-namespace-secret.yaml  # Namespace only (secrets from Vault)
│   ├── mysql-configmap.yaml     # MySQL configuration
│   └── mysql-statefulset.yaml   # MySQL StatefulSet
├── vault-secrets/                # Vault integration
│   ├── README.md                 # Detailed Vault setup guide
│   ├── setup-vault-approle.sh   # Vault AppRole configuration
│   ├── deploy-external-secrets.sh # Deploy ESO configuration
│   ├── validate-secrets.sh      # Validate secret synchronization
│   ├── *-secretstore.yaml       # SecretStore configurations
│   └── *-external-secret.yaml   # ExternalSecret resources
└── deploy-all.sh                 # Complete deployment script
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes cluster** with kubectl configured
2. **Vault installed** and accessible via NodePort 30090 (from infra-fatih)
3. **External Secrets Operator** installed:
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
   ```

### Complete Deployment

```bash
# Deploy everything with one command
./deploy-all.sh
```

This script will:
1. ✅ Verify all prerequisites
2. 🔐 Configure Vault with AppRole authentication
3. 📡 Deploy External Secrets configuration
4. 🗄️ Deploy MySQL with Vault-managed secrets
5. 📱 Deploy applications to dev and prod environments
6. ✅ Validate the deployment

### Manual Deployment Steps

If you prefer step-by-step deployment:

```bash
# 1. Setup Vault integration
cd vault-secrets/
./setup-vault-approle.sh
./deploy-external-secrets.sh

# 2. Deploy MySQL
cd ../mysql/
kubectl apply -f .

# 3. Deploy applications
cd ../app/
kubectl apply -k overlays/dev/     # Dev environment
kubectl apply -k overlays/prod/    # Prod environment
```

## 🔐 Secrets Management

### Vault Integration

This project uses HashiCorp Vault for centralized secrets management:

- **AppRole Authentication**: Secure machine-to-machine authentication
- **Environment Separation**: Different secrets for dev/prod environments  
- **Automatic Synchronization**: External Secrets Operator keeps secrets up-to-date
- **No Hardcoded Secrets**: All sensitive data stored in Vault

### Secret Structure in Vault

```
secret/
├── javdes/
│   ├── dev/database/     # Dev database connection
│   └── prod/database/    # Prod database connection
└── mysql/
    ├── dev/root/         # Dev MySQL root password
    └── prod/root/        # Prod MySQL root password
```

### Environment-Specific Secrets

- **Dev Environment**: Uses `vault-approle-dev` for authentication
- **Prod Environment**: Uses `vault-approle-prod` for authentication
- **Database**: Uses `vault-approle-database` for MySQL secrets

## 🏷️ Naming Conventions

- **Application Name**: `app-javdes` (consistent across all manifests)
- **Environments**: `dev`, `prod`
- **Namespaces**: `dev`, `prod`, `database`
- **Secrets**: `db-secret`, `mysql-root-secret`
- **Services**: `app-javdes-service`
- **Ingress**: `app-javdes-ingress`

## 🌐 Application Access

After deployment, applications are accessible via ingress:

- **Development**: `http://app-javdes-dev.local`
- **Production**: `http://app-javdes-prod.local`

Add these to your `/etc/hosts` file:
```bash
<INGRESS_IP> app-javdes-dev.local
<INGRESS_IP> app-javdes-prod.local
```

## 📊 Monitoring and Validation

### Check Deployment Status
```bash
# Check all resources
kubectl get all -n dev
kubectl get all -n prod
kubectl get all -n database

# Check External Secrets
kubectl get externalsecrets -A
kubectl get secretstores -A
```

### Validate Secret Synchronization
```bash
cd vault-secrets/
./validate-secrets.sh
```

### Check Application Health
```bash
# Application logs
kubectl logs -f deployment/app-javdes -n dev
kubectl logs -f deployment/app-javdes -n prod

# MySQL logs
kubectl logs -f mysql-0 -n database
```

## 🔧 Troubleshooting

### External Secrets Issues
```bash
# Check ExternalSecret status
kubectl describe externalsecret db-secret -n dev

# Check External Secrets Operator logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

### Vault Connectivity
```bash
# Test Vault access
WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
curl -s http://$WORKER_IP:30090/v1/sys/health
```

### Application Issues
```bash
# Check pod status
kubectl get pods -n dev -o wide
kubectl describe pod <pod-name> -n dev

# Check service connectivity  
kubectl get svc -n dev
kubectl get endpoints -n dev
```

## 🔄 Updates and Maintenance

### Updating Application
```bash
# Update dev environment
kubectl apply -k app/overlays/dev/

# Update prod environment  
kubectl apply -k app/overlays/prod/
```

### Updating Secrets
Update secrets in Vault, and External Secrets Operator will automatically sync them within 5 minutes.

### Rotating AppRole Credentials
```bash
cd vault-secrets/
./setup-vault-approle.sh  # Generates new credentials
./deploy-external-secrets.sh  # Updates Kubernetes secrets
```

## 🧹 Cleanup

```bash
# Remove applications
kubectl delete -k app/overlays/dev/
kubectl delete -k app/overlays/prod/

# Remove MySQL
kubectl delete -f mysql/

# Remove External Secrets configuration
kubectl delete -f vault-secrets/

# Remove namespaces
kubectl delete namespace dev prod database
```

## 🤝 Contributing

When making changes:

1. Test in dev environment first
2. Validate secret synchronization
3. Check application functionality
4. Apply to prod environment
5. Update documentation if needed

---

**Project**: JavDes Test Scenario App Manifests  
**Author**: fatihgumush@gmail.com
