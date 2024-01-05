variable "hostname" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "default_root_object" {
  type = string
  default = "index.html"
}

variable "resolve_path_to_root_object" {
  type = bool
  default = true
}
