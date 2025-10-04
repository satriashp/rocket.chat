# ----------------------
# Create ArgoCD namespace
# ----------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  lifecycle {
    ignore_changes   = [metadata]
    prevent_destroy  = false
  }
}

# ----------------------
# Install ArgoCD (core)
# ----------------------
resource "null_resource" "argocd_install" {
  depends_on = [kubernetes_namespace.argocd]

  provisioner "local-exec" {
    command = "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${var.argocd_version}/manifests/core-install.yaml"
  }
}

# ----------------------
# Wait for ArgoCD deployments
# ----------------------
resource "null_resource" "wait_argocd_ready" {
  depends_on = [null_resource.argocd_install]

  provisioner "local-exec" {
    command = <<EOT
bash script/wait_for_deployment.sh argocd argocd-repo-server 180
bash script/wait_for_deployment.sh argocd argocd-redis 180
bash script/wait_for_deployment.sh argocd argocd-applicationset-controller 180
EOT
  }
}

# ----------------------
# Generate server.secretkey
# ----------------------
resource "null_resource" "argocd_secretkey" {
  depends_on = [null_resource.wait_argocd_ready]

  provisioner "local-exec" {
    command = <<EOT
EXISTING_KEY=$(kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.server.secretkey}' 2>/dev/null || echo "")
if [ -z "$EXISTING_KEY" ]; then
  KEY=$(head -c 32 /dev/urandom | base64)
  kubectl patch secret argocd-secret -n argocd --type merge -p "$(cat <<JSON
{
  "stringData": {
    "server.secretkey": "$KEY"
  }
}
JSON
)"
fi
EOT
  }
}

# ----------------------
# Apply root ArgoCD Application (App-of-Apps)
# ----------------------
resource "null_resource" "argocd_app_main" {
  depends_on = [null_resource.argocd_secretkey]

  provisioner "local-exec" {
    command = <<EOT
kubectl apply -f ../../argocd/project.yaml
kubectl apply -f ../../argocd/main.yaml
EOT
  }
}

# ----------------------
# Create Cloudflare secret for cert-manager
# ----------------------
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  lifecycle {
    ignore_changes  = [metadata]
    prevent_destroy = false
  }
}

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata]
  }
}
