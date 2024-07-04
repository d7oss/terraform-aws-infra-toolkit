variable "engine_version" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "name" {
  type = string
}

variable "node_type" {
  type = string
}

variable "parameter_group_family" {
  type = string
}

variable "subnet_group_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  default = null
}

variable "vpc_id" {
  type = string
}
