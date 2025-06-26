#!/bin/bash

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

echo "Namespaces created successfully!"

# Label namespaces
kubectl label namespace dev environment=dev --overwrite
kubectl label namespace prod environment=prod --overwrite
kubectl label namespace database environment=shared --overwrite

echo "Namespace labels applied!"
