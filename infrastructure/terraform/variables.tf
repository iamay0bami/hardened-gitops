variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "realworld-gitops"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Must be staging or production."
  }
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "6.7.3"
}

variable "vault_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.27.0"
}
