variable "name" {
  type = string
}

variable "elasticsearch_version" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = number
  default = 1
}

variable "volume_size" {
  type = number
}

variable "vpc_options_if_private" {
  type = object({
    vpc_id = string
    subnet_ids = list(string)
    ingress_security_groups = map(string)
    extra_security_group_ids = list(string)
  })
  default = null
}

variable "availability_zone_count" {
  type = number
  default = 1
}

variable "hostname" {
  type = string
  default = null
}

variable "acm_certificate_arn" {
  type = string
  default = null
}

variable "enable_authentication" {
  type = bool
  default = false
}

variable "master_username" {
  type = string
  default = "master"
}
