# 🚀 Rocket.Chat GitOps Demo with k3d + ArgoCD

This repository demonstrates a **GitOps-based deployment** of [Rocket.Chat](https://www.rocket.chat/) using [ArgoCD](https://argo-cd.readthedocs.io/) Core component on a local [k3d](https://k3d.io/) Kubernetes cluster.

It is designed as a **showcase demo** for interviews and learning — not for production.
The goal is to demonstrate:
- Bootstrapping Kubernetes environments with `k3d`
- Installing and managing apps via ArgoCD (`app-of-apps` pattern)
- Using sync waves to enforce dependencies (cert-manager → Traefik → Rocket.Chat)
- Handling DNS/SSL certificates with cert-manager + Cloudflare DNS01 challenge
- Idempotent bootstrap scripting

---

## 📂 Repository Structure

```
.
├── README.md
├── argocd
│   ├── apps
│   │   ├── cert-manager
│   │   │   └── application.yaml
│   │   ├── certificates
│   │   │   ├── application.yaml
│   │   │   ├── domain-certificate.yaml
│   │   │   ├── kustomization.yaml
│   │   │   └── lets-encrypt-cluster-issuer.yaml
│   │   ├── kustomization.yaml
│   │   ├── rocketchat
│   │   │   ├── application.yaml
│   │   │   └── httproute
│   │   │       ├── rocketchat-backend.yaml
│   │   │       └── rocketchat-redirect.yaml
│   │   └── traefik
│   │       └── application.yaml
│   ├── main.yaml
│   └── project.yaml
├── bootstrap
│   ├── script
│   │   └── bootstrap.sh
│   └── terraform
│       ├── README.md
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── data
└── k3d.yaml

```
---

## ⚙️ Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [k3d](https://k3d.io/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Cloudflare account & API token (for DNS-01 challenge with Let’s Encrypt)
- A domain managed via Cloudflare (e.g. `*.satriashp.cloud`)
---

## ▶️ Usage

1. Clone this repo:

    ```bash
    git clone https://github.com/satriashp/rocket.chat-demo.git
    cd rocket.chat-demo/bootstrap/script
    ```

2. Export your Cloudflare API token:

    ```bash
    export CLOUDFLARE_API_TOKEN=<your-token>
    ```

3. Run the bootstrap script:

    ```
    ./bootstrap.sh
    ```

This will:
* Create a local k3d cluster (rocket.chat)
* Install ArgoCD (core installation)
* Apply ArgoCD Project and Main app (app-of-apps)
* Create a cloudflare-api-token-secret in cert-manager namespace

---

## 🌐 Certificates
The repo configures:
* cert-manager with Let’s Encrypt (DNS-01 challenge via Cloudflare)
* A ClusterIssuer that uses the cloudflare-api-token-secret
* Certificates for *.satriashp.cloud (configured inside argocd/apps/certificates/)

---

## ⚠️ Known Limitations
This setup is for demo purposes only.
Some limitations to be aware of:

1. Cloudflare Dependency
    * Certificates rely on Cloudflare DNS API.
    * The CLOUDFLARE_API_TOKEN must be exported manually before bootstrap.
    * No secret manager integration (Vault / External Secrets Operator).

2. Static Domain & Email
    * Domain name and Cloudflare account email are hardcoded in manifests.
    * Changing these requires editing manifests or values in Git.
    * In production, you’d handle this dynamically via overlays, Helm values, or ApplicationSet.

3. Multi-Tenant Support
    * Each client would currently require a separate repo, branch or folder.
    * For real multi-tenant setups, you’d use ArgoCD ApplicationSet (with Helm values per client) or Kustomize overlays.
    * This repo keeps it simple to focus on the app-of-apps pattern.

4. Secret Management
    * Secrets are applied via kubectl create secret in bootstrap script.
    * In production, secrets should be managed by Vault, SOPS, or External Secrets Operator.

5. Sync & Health Checks
    * This relies on ArgoCD sync waves (cert-manager → traefik → rocketchat).
    * If cert-manager CRDs are not ready when Traefik applies certificates, sync may temporarily fail until reconciled.
    * No retry backoff logic in bootstrap, relies on ArgoCD’s reconciliation.

## 🎯 Why This Demo?
This project is intended as a portfolio piece to demonstrate:
* GitOps workflow with ArgoCD
* Automated environment bootstrap with idempotent scripting
* Helm-based application management
* Handling SSL/TLS certificates via DNS provider
* Awareness of real-world production considerations and trade-offs

## Maintainer

Satria Sahputra – satriashp.tech@gmail.com