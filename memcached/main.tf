module "security_group" {
  /*
  The security group of the Memcached
  */
  source = "emyller/security-group/aws"
  version = "~> 1.0"

  name = "ec-${var.name}"
  vpc_id = var.vpc
  ingress_security_groups = {
    for name, security_group_id in var.ingress_security_groups:
    (name) => {
      protocol = "tcp"
      port = 11211
      security_group_id = security_group_id
    }
  }
}

resource "aws_elasticache_cluster" "main" {
  /*
  The Memcached instance
  */
  cluster_id = var.name
  engine = "memcached"
  node_type = "cache.t3.micro"
  num_cache_nodes = 1
  parameter_group_name = aws_elasticache_parameter_group.main.name
  engine_version = "1.4.34"
  port = 11211
  security_group_ids = [module.security_group.id]
  subnet_group_name = "prod"
}

resource "aws_elasticache_parameter_group" "main" {
  /*
  Parameter group for the Memcached instance
  */
  name = "memcached-${var.name}"
  family = "memcached1.4"
}
