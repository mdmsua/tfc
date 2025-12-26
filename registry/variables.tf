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

variable "modsecurity_version" {
  description = "ModSecurity version"
  type        = string
  default     = "4.21.0"
}
