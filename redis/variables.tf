variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  default = null
}

variable "ingress_security_groups" {
  type = map(string)
  default = {}
}

variable "engine_version" {
  type = string
}

variable "node_type" {
  type = string
}

variable "num_shards" {
  type = number
  default = 1
}

variable "num_replicas_per_shard" {
  type = number
  default = 0
}

variable "parameter_group_family" {
  type = string
}

variable "extra_users" {
  type = map(string)
  default = {}
}
