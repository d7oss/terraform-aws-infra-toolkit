variable "name" {
  type = string
}

variable "vpc" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "acu_max_capacity" {
  type = number
}
