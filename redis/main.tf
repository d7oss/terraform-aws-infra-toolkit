module "security_group" {
  /*
  The security group of the Redis cluster
  */
  source = "emyller/security-group/aws"
  version = "~> 1.0"

  name = "ec-${var.name}"
  vpc_id = var.vpc
  ingress_security_groups = {
    for name, security_group_id in var.ingress_security_groups:
    (name) => {
      protocol = "tcp"
      port = 6379
      security_group_id = security_group_id
    }
  }
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
  subnet_group_name = try(
    one(aws_elasticache_subnet_group.optional[*].name),
    var.subnet_group_name,
  )
}

resource "aws_elasticache_parameter_group" "main" {
  /*
  Parameter group for the Redis cluster
  */
  name = var.name
  family = var.parameter_group_family

  # TODO: Allow custom parameters
}

resource "aws_elasticache_subnet_group" "optional" {
  /*
  Subnet group for the Redis cluster

  Only manage a subnet group if subnet IDs were given.
  */
  count = var.subnet_ids == null ? 0 : 1

  name = var.name
  subnet_ids = var.subnet_ids
}
