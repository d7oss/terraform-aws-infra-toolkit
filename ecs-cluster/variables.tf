variable "name" {
  type = string
}

variable "capacity_providers" {
  type = map(object({
    weight = number
    base = optional(number)
  }))

  validation {
    # Make sure keys within var.capacity_providers are valid capacity providers, e.g. FARGATE, FARGATE_SPOT
    condition = length(setsubtract(keys(var.capacity_providers), ["FARGATE", "FARGATE_SPOT"])) == 0
    error_message = "Invalid capacity provider name. Valid values are FARGATE and FARGATE_SPOT."
  }
}
