variable "name" {
  type = string
  description = "Application name."
}

variable "vpc" {
  type = string
  description = "The VPC to place resources in."
}

variable "certificate_domain" {
  type = string
  description = "The primary domain name of the ACM certificate."
}

variable "dns_zone_id" {
  type = string
  description = "The Zone ID in Route53 for the application domain."
}

variable "manage_tls" {
  type = bool
  description = "Whether to manage the TLS certificates."
}

variable "services" {
  type = map(object({
    min_instances = optional(number)
    max_instances = optional(number)
    cpu_threshold = optional(number)
    memory_threshold = optional(number)
    memory = number
    command = optional(list(string))
    cpu_units = number
    docker_image = string
    docker_tag = optional(string)
    docker_image_source = optional(string)
    hostname = optional(string)
    redirect_apex_to_www = optional(bool)
    redirect_www_to_apex = optional(bool)
    load_balancer = optional(string)
    http_port = optional(number)
    env = optional(map(string))
    secrets = optional(map(string))
    health_check_path = optional(string)
    health_check_status_codes = optional(list(number))
    cache_paths = optional(list(string))
    mount_files = optional(map(string))
    file_system = optional(object({
      id = string
      root_directory = string
      mount_path = string
    }))
  }))
  description = "Map of services to deploy."
}

variable "env" {
  type = map(string)
  default = {}
}

variable "secrets" {
  type = map(string)
  default = {}
}

variable "iam_user_permissions" {
  type = map(object({
    actions = list(string)
    resources = list(string)
  }))
  default = null
}
