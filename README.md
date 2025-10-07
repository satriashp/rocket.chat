# 🚀 Rocket.Chat GitOps Demo with k3d + ArgoCD + Kubernetes Operator (with kubebuilder)

This repository demonstrates a **GitOps-based deployment** of [Rocket.Chat](https://www.rocket.chat/) using [ArgoCD](https://argo-cd.readthedocs.io/) Core component on a local [k3d](https://k3d.io/) Kubernetes cluster.

It is designed as a **showcase demo** for interviews and learning — not for production.
The goal is to demonstrate:
- Bootstrapping Kubernetes environments with `k3d`
- Installing and managing apps via ArgoCD (`app-of-apps` pattern)
- Using sync waves to enforce dependencies (cert-manager → Traefik → Rocket.Chat)
- Handling DNS/SSL certificates with cert-manager + Cloudflare DNS01 challenge
- Idempotent bootstrap scripting
- Basic understanding of Kubernetes Operator concepts

---

## 📂 Repository Structure
<details>
    <summary>Click to expand repository folders and files</summary>

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
│   │   ├── monitoring
│   │   │   ├── application.yaml
│   │   │   ├── dashboard
│   │   │   │   └── rocketchat.yaml
│   │   │   └── httproute
│   │   │       ├── grafana-backend.yaml
│   │   │       ├── grafana-redirect.yaml
│   │   │       └── referencesgrant.yaml
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
│       ├── providers.tf
│       ├── script
│       │   └── wait_for_deployment.sh
│       └── variables.tf
├── data
├── k3d.yaml
├── rocketchat-backup-operator
│   ├── Dockerfile
│   ├── Makefile
│   ├── PROJECT
│   ├── README.md
│   ├── api
│   │   └── v1alpha1
│   │       ├── groupversion_info.go
│   │       ├── rocketchatbackup_types.go
│   │       └── zz_generated.deepcopy.go
│   ├── bin
│   ├── cmd
│   │   └── main.go
│   ├── config
│   │   ├── crd
│   │   │   ├── bases
│   │   │   │   └── apps.satriashp.cloud_rocketchatbackups.yaml
│   │   │   ├── kustomization.yaml
│   │   │   └── kustomizeconfig.yaml
│   │   ├── default
│   │   │   ├── cert_metrics_manager_patch.yaml
│   │   │   ├── kustomization.yaml
│   │   │   ├── manager_metrics_patch.yaml
│   │   │   └── metrics_service.yaml
│   │   ├── manager
│   │   │   ├── configmap.yaml
│   │   │   ├── kustomization.yaml
│   │   │   ├── manager.yaml
│   │   │   └── pvc.yaml
│   │   ├── network-policy
│   │   │   ├── allow-metrics-traffic.yaml
│   │   │   └── kustomization.yaml
│   │   ├── prometheus
│   │   │   ├── kustomization.yaml
│   │   │   ├── monitor.yaml
│   │   │   └── monitor_tls_patch.yaml
│   │   ├── rbac
│   │   │   ├── kustomization.yaml
│   │   │   ├── leader_election_role.yaml
│   │   │   ├── leader_election_role_binding.yaml
│   │   │   ├── metrics_auth_role.yaml
│   │   │   ├── metrics_auth_role_binding.yaml
│   │   │   ├── metrics_reader_role.yaml
│   │   │   ├── rocketchatbackup_admin_role.yaml
│   │   │   ├── rocketchatbackup_editor_role.yaml
│   │   │   ├── rocketchatbackup_viewer_role.yaml
│   │   │   ├── role.yaml
│   │   │   ├── role_binding.yaml
│   │   │   └── service_account.yaml
│   │   └── samples
│   │       ├── apps_v1alpha1_rocketchatbackup.yaml
│   │       ├── kustomization.yaml
│   │       └── restore_job.yaml
│   ├── go.mod
│   ├── go.sum
│   ├── hack
│   │   └── boilerplate.go.txt
│   ├── internal
│   │   └── controller
│   │       ├── rocketchatbackup_controller.go
│   │       ├── rocketchatbackup_controller_test.go
│   │       └── suite_test.go
│   └── test
│       ├── e2e
│       │   ├── e2e_suite_test.go
│       │   └── e2e_test.go
│       └── utils
│           └── utils.go
└── tools
    ├── manifests
    │   ├── configmap.yaml
    │   ├── cronjob.yaml
    │   └── pvc.yaml
    ├── mongodump.sh
    ├── mongorestore.sh
    └── notes.md

```
> This is a basic structure for demonstration purposes.

</details>
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

## 🚀 Kubernetes Operator
1. 🛠 Build and Deploy the Operator
    ```bash
    make docker-build docker-push IMG=<your-registry>/rocketchat-operator:latest
    make deploy IMG=<your-registry>/rocketchat-operator:latest
    ```
2. 📄 Apply sample a Backup Custom Resource
    ```bash
    kubectl apply -f rocketchat-backup-operator/config/samples/apps_v1alpha1_rocketchatbackup.yaml
    ```
    This will create a simple RocketChatBackup resource that triggers a basic backup job in the cluster. It’s a minimal demo to illustrate how a Kubernetes Operator can work.


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
* Understanding the basic and practical concept of Kubernetes Operator

## Maintainer

Satria Sahputra – satriashp.tech@gmail.com