# Infrastructure Setup

This directory contains all the infrastructure-related Kubernetes manifests for the BankApp project.

## Directory Structure

```
k8s-manifests/infrastructure/
├── cert-manager/
│   └── selfsigned-cluster-issuer.yaml     # Self-signed ClusterIssuer and CA
├── certificates/
│   └── bankapp-certificates.yaml          # Application-specific certificates
├── ingress-nginx/                         # (Future: Ingress controller configs)
└── kustomization.yaml                     # Infrastructure kustomization
```

## Prerequisites

1. **cert-manager** must be installed in the cluster:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
   ```

2. **ingress-nginx** controller should be installed and running

3. **Namespaces** should exist:
   ```bash
   kubectl create namespace dev
   kubectl create namespace prod
   ```

## Setup Instructions

### 1. Quick Setup (Recommended)

Run the automated setup script:

```bash
cd /path/to/app-fatih-manifests
./scripts/setup-infrastructure.sh
```

### 2. Manual Setup

#### Step 1: Create ClusterIssuers
```bash
kubectl apply -f k8s-manifests/infrastructure/cert-manager/selfsigned-cluster-issuer.yaml
```

#### Step 2: Wait for ClusterIssuers to be ready
```bash
kubectl get clusterissuer
```

#### Step 3: Create certificates
```bash
kubectl apply -f k8s-manifests/infrastructure/certificates/bankapp-certificates.yaml
```

#### Step 4: Verify certificates
```bash
kubectl get certificates -n dev
kubectl get certificates -n prod
```

## Certificate Details

### ClusterIssuers

1. **selfsigned-cluster-issuer**: Basic self-signed issuer for creating a CA
2. **selfsigned-ca-issuer**: CA issuer that uses the self-signed CA certificate

### Certificates

- **bankapp-dev-tls**: Certificate for `bankapp-dev.local` (dev namespace)
- **bankapp-prod-tls**: Certificate for `bankapp-prod.local` (prod namespace)

## Usage in Applications

Applications should reference these certificates in their ingress configurations:

```yaml
spec:
  tls:
  - hosts:
    - bankapp-dev.local
    secretName: bankapp-dev-tls  # References the certificate secret
```

## Troubleshooting

### Certificate not ready
```bash
kubectl describe certificate bankapp-dev-tls -n dev
kubectl describe clusterissuer selfsigned-ca-issuer
```

### Check cert-manager logs
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

### Recreate certificates
```bash
kubectl delete certificate bankapp-dev-tls -n dev
kubectl apply -f k8s-manifests/infrastructure/certificates/bankapp-certificates.yaml
```

## Security Notes

- These are **self-signed certificates** for development/testing
- For production, consider using:
  - Let's Encrypt with ACME issuer
  - Internal CA certificates
  - Commercial certificates

## Next Steps

After infrastructure setup:

1. Apply application manifests
2. Update `/etc/hosts` for local testing:
   ```
   <INGRESS_IP> bankapp-dev.local
   <INGRESS_IP> bankapp-prod.local
   ```
3. Access applications via HTTPS
