variable "name" {
  type = string
}

variable "description" {
  type = string
  default = null
}

variable "vpc_id" {
  type = string
}

variable "ingress_with_source_security_group_id" {
  type = map(object({
    rule = string  # See https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/v5.0.0/rules.tf
    source_security_group_id = string
  }))
  default = {}
}

variable "ingress_with_cidr_blocks" {
  type = map(object({
    rule = string  # See https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/v5.0.0/rules.tf
    cidr_blocks = list(string)
  }))
  default = {}
}
