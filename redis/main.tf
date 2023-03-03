module "security_group" {
  /*
  The security group of the Redis
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
  The Redis instance
  */
  cluster_id = var.name
  engine = "redis"
  node_type = var.node_type
  num_cache_nodes = 1
  parameter_group_name = aws_elasticache_parameter_group.main.name
  engine_version = var.engine_version
  port = 6379
  security_group_ids = [module.security_group.id]
  subnet_group_name = "prod"
}

resource "aws_elasticache_parameter_group" "main" {
  /*
  Parameter group for the Redis instance
  */
  name = var.name
  family = var.parameter_group_family
}
