variable "apply_immediately" {
  type = bool
  default = false
}

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
  default = "8.0"
}

variable "engine" {
  type = string
  default = "aurora-mysql"
}

variable "engine_mode" {
  type = string
  default = "provisioned"
}

variable "instance_type" {
  type = string
  default = "db.t4g.medium"
}

variable "instance_count" {
  type = number
  default = 1
}
