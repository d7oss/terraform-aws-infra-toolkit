variable "allocated_storage" {
  type = number
}

variable "apply_immediately" {
  type = bool
  default = true
}

variable "backup_retention_period" {
  type = number
  default = 7
}

variable "backup_window" {
  type = string
  default = "02:00-03:00"
}

variable "engine" {
  type = string
  default = null

  validation {
    condition = var.engine != null || var.restore_from_snapshot_identifier != null
    error_message = "'engine' can only be null if restoring from a snapshot."
  }
}

variable "engine_version" {
  type = string
  default = null

  validation {
    condition = var.engine_version != null || var.restore_from_snapshot_identifier != null
    error_message = "'engine_version' can only be null if restoring from a snapshot."
  }
}

variable "extra_parameters" {
  type = map(string)
  default = {}
}

variable "extra_security_group_ids" {
  type = list(string)
  default = []
}

variable "final_snapshot_identifier" {
  type = string
  default = null
}

variable "hostname" {
  type = string
  default = null
}

variable "hostname_zone_id" {
  type = string
  default = null
}

variable "ingress_security_groups" {
  type = map(string)
}

variable "instance_class" {
  type = string
}

variable "multi_az" {
  type = bool
  default = false
}

variable "name" {
  type = string
}

variable "publicly_accessible" {
  type = bool
  default = false
}

variable "restore_from_snapshot_identifier" {
  type = string
  default = null
}

variable "security_group_description" {
  type = string
  default = null
}

variable "skip_final_snapshot" {
  type = bool
  default = true
}

variable "storage_type" {
  type = string
  default = "gp2"
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
