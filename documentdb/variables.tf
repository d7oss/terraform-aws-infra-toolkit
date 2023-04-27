variable "name" {
  type = string
}

variable "instance_count" {
  type = number
  default = 1
}

variable "instance_class" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_group_name" {
  type = string
  default = null
}

variable "subnet_ids" {
  type = list(string)
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "extra_security_group_ids" {
  type = list(string)
  default = []
}
