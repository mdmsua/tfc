variable "tfc_azure_dynamic_credentials" {
  description = "Object containing Azure dynamic credentials configuration"
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "argocd_version" {
  description = "ArgoCD version"
  type        = string
  default     = "9.0.5"
}

variable "admins" {
  description = "Admins"
  type        = list(string)
  default     = ["6b1aa092-b266-49f3-be05-341fff39cd59"]
}

variable "repository_name" {
  description = "GitHub repository"
  type        = string
  default     = "mdmsua/tfc"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}
