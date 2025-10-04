#!/bin/bash
set -euo pipefail

# Get the absolute path of the directory where this script lives
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CLUSTER_NAME="rocket.chat"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v3.1.7"

# Ensure required env var is set
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "❌ CLOUDFLARE_API_TOKEN is not set!"
  echo "Please export your Cloudflare API token before running this script:"
  echo ""
  echo "  export CLOUDFLARE_API_TOKEN=<your-api-token>"
  echo ""
  echo "This is required for cert-manager ClusterIssuer to complete DNS-01 challenges with Let's Encrypt."
  exit 1
fi

echo "✅ CLOUDFLARE_API_TOKEN detected"

echo "🚀 Bootstrapping local Kubernetes with k3d + ArgoCD"
echo
# Create cluster if not exists
if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  echo "✅ Cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
  echo "⏳ Creating cluster '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" --config $SCRIPT_DIR/../../k3d.yaml
fi

# wait until cluster ready
echo
echo "⏳ Wait cluster to be ready ..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo
# Create namespace for ArgoCD if not exists
if kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "✅ Namespace '${ARGOCD_NAMESPACE}' already exists."
else
  echo "⏳ Creating namespace '${ARGOCD_NAMESPACE}'..."
  kubectl create namespace "${ARGOCD_NAMESPACE}"
fi

echo
# Install ArgoCD (core components only)
if kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=180s >/dev/null 2>&1; then
  echo "✅ ArgoCD already installed."
else
  echo "⏳ Installing ArgoCD (${ARGOCD_VERSION})..."

  kubectl apply -n "${ARGOCD_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/core-install.yaml"
fi

# Wait for ArgoCD components to be ready
echo
echo "⏳ Waiting for ArgoCD Core components to be available..."
kubectl wait --for=condition=Available deployment/argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=180s
kubectl wait --for=condition=Available deployment/argocd-redis -n "${ARGOCD_NAMESPACE}" --timeout=180s
kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=180s

# Generate server secret key
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
kubectl apply -f $SCRIPT_DIR/../../argocd/project.yaml
kubectl apply -f $SCRIPT_DIR/../../argocd/main.yaml

# Apply secret (for cert-manager DNS01 challenge)
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token="${CLOUDFLARE_API_TOKEN}" \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Cloudflare API token secret applied to cert-manager namespace"