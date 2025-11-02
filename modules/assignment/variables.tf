variable "principal_id" {
  description = "Principal ID"
  type        = string
}

variable "roles" {
  description = "Roles map"
  type        = map(set(string))
}
