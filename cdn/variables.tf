variable "domain" {
  type = string
}

variable "tls_certificate_arn" {
  type = string
}

variable "s3_bucket_regional_domain_name" {
  type = string
}

variable "behaviors_by_path" {
  type = map(object({
    allowed_methods = list(string)
    cached_methods = list(string)
    cache = optional(bool, true)
    compress = optional(bool, false)
    query_string = optional(bool, false)
    viewer_request_handler_js_code = optional(string, null)
  }))
  default = {}
}

variable "default_root_object" {
  type = string
  default = null
}
