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

variable "image" {
  type        = string
  description = "Agent image"
  default     = "ghcr.io/cariad-mega/tfc-agent:main"
}

variable "image_registry_password" {
  type        = string
  description = "Image registry password"
  sensitive   = true
}
