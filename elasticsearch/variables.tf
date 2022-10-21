variable "name" {
  type = string
}

variable "vpc" {
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}
