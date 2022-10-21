variable "namespace" {
  type = string
  description = "Blog namespace. Name used on the database, EFS and other resources."
}

variable "dominio" {
  type = string
  description = "Blog domain."
}

variable "versao_wordpress" {
  type = string
  description = "WordPress version."
}
