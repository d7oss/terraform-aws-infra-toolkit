variable "namespace" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ingress_security_groups" {
  type = map(object({
    source_security_group_id = string
    rule = optional(string, "all-all")
  }))
}

variable "extra_security_group_ids" {
  type = list(string)
  default = []
}

variable "http_services" {
  type = map(object({
    cpu = optional(number, 256)
    memory = optional(number, 512)

    containers = map(object({
      image = string
      command = optional(list(string), [])
      cpu = optional(number)
      memory = optional(number)
      environment_variables = optional(map(string), {})
      secrets = optional(map(string), {})
      http = optional(object({
        port = number
        load_balancer_arn = string
        listener_rule = object({
          priority = optional(number)
          hostnames = optional(list(string))
          paths = optional(list(string))
          headers = optional(map(list(string)))
        })
        health_check = object({
          path = string
          status_codes = list(number)
          interval = optional(number, 30)
          healthy_threshold = optional(number, 2)
          unhealthy_threshold = optional(number, 2)
          timeout = optional(number, 5)
        })
      }))
      log_group_name = optional(string)
      log_group_retention_in_days = optional(number, 7)
    }))

    autoscaling = optional(object({
      min_capacity = optional(number, 1)
      max_capacity = optional(number, 1)
      cpu_threshold = optional(number, 80)
      memory_threshold = optional(number, 80)
      scale_in_cooldown = optional(number, 300)
      scale_out_cooldown = optional(number, 60)
    }), {
      min_capacity = 1
      max_capacity = 1
      cpu_threshold = 80
      memory_threshold = 80
      scale_in_cooldown = 300
      scale_out_cooldown = 60
    })

    extra_security_group_ids = optional(list(string), [])
  }))
  default = {}
}

variable "worker_services" {
  type = map(object({
    cpu = optional(number, 256)
    memory = optional(number, 512)

    containers = map(object({
      image = string
      command = optional(list(string), [])
      cpu = optional(number)
      memory = optional(number)
      environment_variables = optional(map(string), {})
      secrets = optional(map(string), {})
      log_group_name = optional(string)
      log_group_retention_in_days = optional(number, 7)
    }))

    autoscaling = optional(object({
      min_capacity = optional(number, 1)
      max_capacity = optional(number, 1)
      cpu_threshold = optional(number, 80)
      memory_threshold = optional(number, 80)
      scale_in_cooldown = optional(number, 300)
      scale_out_cooldown = optional(number, 60)
    }), {
      min_capacity = 1
      max_capacity = 1
      cpu_threshold = 80
      memory_threshold = 80
      scale_in_cooldown = 300
      scale_out_cooldown = 60
    })

    extra_security_group_ids = optional(list(string), [])
  }))
  default = {}
}
