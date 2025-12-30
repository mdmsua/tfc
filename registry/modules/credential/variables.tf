variable "server" {
  description = "Source registry login server"
  type        = string
}

variable "username" {
  description = "Source registry username"
  type        = string
}

variable "password" {
  description = "Source registry password"
  type        = string
  sensitive   = true
}

variable "container_registry_id" {
  description = "Container registry ID"
  type        = string
}

variable "key_vault_id" {
  description = "Key vault ID"
  type        = string

}
