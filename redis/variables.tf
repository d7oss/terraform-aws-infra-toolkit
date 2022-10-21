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
