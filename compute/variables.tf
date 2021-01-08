variable "client_id" {
  type        = string
  default     = "client_id"
  description = "(mandatory) client Id of service principal"
}

variable "client_secret" {
  type        = string
  default     = "client_secret"
  description = "(mandatory) client secret of service principal"
}

variable "subscription_id" {
  type        = string
  default     = "subscription_id"
  description = "(mandatory) azure subscription Id"
}

variable "tenant_id" {
  type        = string
  default     = "tenant_id"
  description = "(mandatory) azure tenant Id"
}

variable "deployment" {
  description = "(mandatory) deployment main tag"
  default     = {}
}

variable "management" {
  default     = {}
  description = "(mandatory) management block"
}