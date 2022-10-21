terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws, aws.use1]
    }
  }
}

locals {
  env = "prod"
}

data "aws_vpc" "main" {
  tags = { Name = local.env }
}

module "dns_zones" {
  /*
  Primary DNS zones
  */
  source = "d7oss/route53/aws//zone"
  version = "~> 0.0"

  for_each = toset([
    var.dominio,
  ])

  name = each.value
}

module "blog" {
  /*
  Module that encapsulate the required infra for a WordPress blog
  */
  source = "../site"
  providers = {
    aws = aws
    aws.use1 = aws.use1
  }

  depends_on = [
    module.dns_zones
  ]

  name = var.namespace
  vpc = data.aws_vpc.main.id
  certificate_domain = var.dominio
  dns_zone_domain = module.dns_zones[var.dominio].name
  manage_tls = true

  services = {
    "blog": {
      hostname = var.dominio
      memory = 512
      cpu_units = 256
      docker_image_source = "dockerhub"
      docker_image = "wordpress"
      docker_tag = var.versao_wordpress
      load_balancer = local.env
      http_port = 80
      file_system = {
        id = module.wordpress_file_system.id
        root_directory = "/"
        mount_path = "/var/www/html"
      }
    }
  }

  env = {
    "WORDPRESS_DB_HOST" = module.database.host
    "WORDPRESS_DB_USER" = module.database.username
    "WORDPRESS_DB_NAME" = module.database.name
  }

  secrets = {
    "WORDPRESS_DB_PASSWORD" = module.database.password
  }
}

module "wordpress_file_system" {
  /*
  EFS mount to store the WordPress install
  */
  source = "../file-system"

  name = "${var.namespace}-wordpress"
  vpc = data.aws_vpc.main.id
  ingress_security_groups = {
    "app" = module.blog.security_group_id
  }
}

module "database" {
  /*
  MySQL database for the WordPress blog
  */
  source = "../database-mysql"

  name = var.namespace
  vpc = data.aws_vpc.main.id
  ingress_security_groups = {
    "app" = module.blog.security_group_id
  }
}
