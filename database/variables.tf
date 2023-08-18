variable "name" {
  type = string
}

variable "restore_from_cluster" {
  type = string
  default = null
}

variable "vpc" {
  type = string
}

variable "subnet_group_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  default = null
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "engine" {
  type = string
  default = null
}

variable "engine_version" {
  type = string
  default = null
}

variable "acu_min_capacity" {
  type = number
  default = 0.5
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

variable "backup_retention_period" {
  type = number
  default = 7
}

variable "preferred_backup_window" {
  type = string
  default = "02:00-03:00"
}

variable "skip_final_snapshot" {
  type = bool
  default = false
}

variable "apply_immediately" {
  type = bool
  default = false
}

variable "preferred_maintenance_window" {
  type = string
  default = "Sun:03:00-Sun:04:00"
}
