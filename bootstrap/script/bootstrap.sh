#!/bin/bash
set -euo pipefail

CLUSTER_NAME="rocket.chat"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v3.1.7"

echo "🚀 Bootstrapping local Kubernetes with k3d + ArgoCD"
echo
# Create cluster if not exists
if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  echo "✅ Cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
  echo "⏳ Creating cluster '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" --config ../../k3d.yaml
fi

# Create namespace for ArgoCD if not exists
if kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "✅ Namespace '${ARGOCD_NAMESPACE}' already exists."
else
  echo "⏳ Creating namespace '${ARGOCD_NAMESPACE}'..."
  kubectl create namespace "${ARGOCD_NAMESPACE}"
fi

# Install ArgoCD (core components only)
if kubectl get deploy -n "${ARGOCD_NAMESPACE}" argocd-applicationset-controller >/dev/null 2>&1; then
  echo "✅ ArgoCD already installed."
else
  echo "⏳ Installing ArgoCD (${ARGOCD_VERSION})..."

  kubectl apply -n "${ARGOCD_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/core-install.yaml"
fi

# Wait for ArgoCD components to be ready
echo
echo "⏳ Waiting for ArgoCD ApplicationSet controller to be available..."

kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}"

if [ -z "$(kubectl get secret argocd-secret -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.data.server\.secretkey}' 2>/dev/null)" ]; then
  echo
  echo "⏳ Generate server.secretkey"

  KEY=$(head -c 32 /dev/urandom | base64)
  kubectl patch secret argocd-secret -n "${ARGOCD_NAMESPACE}" --type='merge' -p="{\"stringData\":{\"server.secretkey\":\"${KEY}\"}}"
else
  echo "✅ server.secretkey already exists"
fi

echo
echo "🎉 Bootstrap complete! ArgoCD is running in namespace '${ARGOCD_NAMESPACE}'."

echo
echo "Initiate main application ..."
kubectl apply -f ../../argocd/project.yaml
# kubectl apply -f ../../argocd/main.yaml