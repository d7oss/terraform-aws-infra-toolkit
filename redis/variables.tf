variable "name" {
  type = string
}

variable "node_type" {
  type = string
  default = "cache.t3.micro"
}

variable "vpc" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "engine_version" {
  type = string
  default = "2.8.24"
}

variable "parameter_group_family" {
  type = string
  default = "redis2.8"
}

variable "subnet_group_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  default = null
}
