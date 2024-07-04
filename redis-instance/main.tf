locals {
  # Whether to manage the subnet group
  is_managing_subnet_group = var.subnet_ids != null
  subnet_group = one(local.is_managing_subnet_group ? aws_elasticache_subnet_group.managed : data.aws_elasticache_subnet_group.reused)
}

resource "aws_elasticache_cluster" "main" {
  /*
  The Redis cluster
  */
  cluster_id = var.name
  engine = "redis"
  node_type = var.node_type
  num_cache_nodes = 1
  parameter_group_name = aws_elasticache_parameter_group.main.name
  engine_version = var.engine_version
  port = 6379
  security_group_ids = [module.security_group.id]
  subnet_group_name = local.subnet_group.name
}

resource "aws_elasticache_parameter_group" "main" {
  /*
  Parameter group for the Redis cluster
  */
  name = var.name
  family = var.parameter_group_family

  # TODO: Allow custom parameters
}

data "aws_elasticache_subnet_group" "reused" {
  /*
  The reused Redis subnet group
  */
  count = local.is_managing_subnet_group ? 0 : 1

  name = var.subnet_group_name
}

resource "aws_elasticache_subnet_group" "managed" {
  /*
  Subnet group for the Redis cluster

  Only manage a subnet group if subnet IDs were given.
  */
  count = local.is_managing_subnet_group ? 1 : 0

  name = var.subnet_group_name
  subnet_ids = var.subnet_ids
}

module "security_group" {
  /*
  The security group for the cache
  */
  source = "../security-group"
  name = "ec-${var.name}"
  description = "${var.name} Redis instance"
  vpc_id = var.vpc_id
  ingress_with_source_security_group_id = {
    for name, sg_id in var.ingress_security_groups: (name) => {
      source_security_group_id = sg_id
      rule = "all-all"
    }
  }
}
