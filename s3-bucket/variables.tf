variable "name" {
  type = string
}

variable "enable_versioning" {
  type = bool
  default = false
}

variable "policy" {
  type = string
  default = null
}

variable "cors_rules" {
  type = list(object({
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), ["*"])
    expose_headers = optional(list(string), ["ETag"])
    max_age_seconds = optional(number, 3600)  # 1 hour
  }))
  default = []
}
