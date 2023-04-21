resource "random_password" "main" {
  length = 24
  override_special = "<>;()&#!^_-"
}

data "aws_rds_engine_version" "main" {
  engine = var.engine
  version = var.engine_version

  # Prevent deprecated versions
  include_all = false

  filter {
    name = "engine-mode"
    values = ["provisioned"]
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = var.name
  engine = data.aws_rds_engine_version.main.engine
  engine_mode = "provisioned"
  engine_version = data.aws_rds_engine_version.main.version
  database_name = "main"
  master_username = "master"
  master_password = random_password.main.result
  db_subnet_group_name = "prod"
  vpc_security_group_ids = [module.security_group.id]

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.acu_max_capacity == null ? [] : [true]
    content {
      max_capacity = var.acu_max_capacity
      min_capacity = 0.5
    }
  }
}

resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count
  cluster_identifier = aws_rds_cluster.main.id
  instance_class = var.instance_class
  engine = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version
}

module "security_group" {
  /*
  Security Group for the database
  */
  source = "emyller/security-group/aws"
  version = "~> 1.0"

  name = "db-${var.name}"
  vpc_id = var.vpc
  ingress_security_groups = {
    for name, security_group_id in var.ingress_security_groups:
    (name) => {
      protocol = "tcp"
      port = aws_rds_cluster.main.port
      security_group_id = security_group_id
    }
  }
}
