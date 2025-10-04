variable "k3d_config_path" {
  type    = string
  default = "../../k3d.yaml"
}

variable "cluster_name" {
  type    = string
  default = "rocket.chat"
}

variable "argocd_version" {
  type    = string
  default = "v3.1.7"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token for cert-manager"
  sensitive   = true
}
