variable "name" {
  type = string
}

variable "vpc" {
  type = string
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "engine" {
  type = string
  default = "aurora-postgresql"
}

variable "engine_version" {
  type = string
  default = null
}

variable "acu_max_capacity" {
  type = number
  default = null
}

variable "instance_class" {
  type = string
  default = "db.t4g.medium"
}

variable "instance_count" {
  type = number
  default = 1
}
