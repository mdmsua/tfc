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
  default     = "1.34"
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

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "dmmo.io"
}

variable "docker_hub_username" {
  description = "Docker hub username"
  type        = string
}

variable "docker_hub_token" {
  description = "Docker hub token"
  type        = string
  sensitive   = true
}

variable "github_app_id" {
  description = "GitHub app ID"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub app installation ID"
  type        = string
}

variable "github_app_pem_file" {
  description = "GitHub app PEM file"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub owner"
  type        = string
}