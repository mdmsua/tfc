variable "github_token" {
  description = "GitHub token"
  type        = string
  sensitive   = true
}

variable "contributors" {
  description = "Registry contributors"
  type        = set(string)
  default     = ["6b1aa092-b266-49f3-be05-341fff39cd59"]
}

variable "docker_hub_token" {
  description = "Access token to docker hub"
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
