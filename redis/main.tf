locals {
  default_users = {
    "root" = "on ~* &* +@all"
  }
}

module "security_group" {
  /*
  The security group for the Redis cluster
  */
  source = "../security-group"
  name = "redis-${var.name}"
  description = "${var.name} Redis cluster"
  vpc_id = var.vpc_id
  ingress_with_source_security_group_id = {
    for description, security_group_id in var.ingress_security_groups:
    (description) => {
      rule = "redis-tcp"
      source_security_group_id = security_group_id
    }
  }
}

module "redis_cluster" {
  source = "terraform-aws-modules/memory-db/aws"
  version = "~> 2.0"

  name = var.name
  engine_version = var.engine_version
  node_type = var.node_type
  num_shards = var.num_shards
  num_replicas_per_shard = var.num_replicas_per_shard

  create_subnet_group = var.subnet_ids != null
  subnet_group_name = var.subnet_group_name
  subnet_ids = var.subnet_ids
  security_group_ids = [module.security_group.id]

  create_parameter_group = true
  parameter_group_family = var.parameter_group_family

  users = {
    for user_name, access_string in merge(local.default_users, var.extra_users):
    (user_name) => {
      user_name = "${var.name}-${user_name}"
      access_string = access_string
      passwords = [random_password.main[user_name].result]
    }
  }
}

resource "random_password" "main" {
  /*
  Random passwords for the all users
  */
  for_each = merge(local.default_users, var.extra_users)

  length = 16
  special = false
}
