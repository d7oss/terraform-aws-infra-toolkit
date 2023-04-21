variable "name" {
  type = string
}

variable "vpc" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "engine_version" {
  type = string
  default = null
}

variable "acu_max_capacity" {
  type = number
}
