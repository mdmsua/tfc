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

variable "principals" {
  description = "Cluster admin principals"
  type        = set(string)
  default     = ["6b1aa092-b266-49f3-be05-341fff39cd59"]
}
