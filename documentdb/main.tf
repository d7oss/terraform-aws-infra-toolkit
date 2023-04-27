resource "random_password" "master" {
  /*
  Random password for the master user
  */
  length = 20
  special = false
}

data "aws_docdb_engine_version" "main" {
  version = var.engine_version
}

resource "aws_docdb_cluster" "main" {
  /*
  The MongoDB-compatible cluster
  */
  engine = "docdb"
  cluster_identifier = var.name
  engine_version = data.aws_docdb_engine_version.main.version

  # Server authentication
  master_username = "master"
  master_password = random_password.master.result

  # Networking
  db_subnet_group_name = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = concat([module.security_group.id], var.extra_security_group_ids)

  # Backup configuration
  backup_retention_period = 3
  preferred_backup_window = "04:00-05:00"
  skip_final_snapshot = true
}

resource "aws_docdb_cluster_instance" "main" {
  /*
  Instances within the cluster
  */
  count = var.instance_count

  cluster_identifier = aws_docdb_cluster.main.cluster_identifier
  instance_class = var.instance_class
  identifier = "${var.name}-${format("%02d", count.index + 1)}"
}

resource "aws_docdb_subnet_group" "main" {
  /*
  Subnet group to place the cluster

  TODO: Add support to reusing one
  */
  name = coalesce(var.subnet_group_name, var.name)
  subnet_ids = var.subnet_ids
}

module "security_group" {
  /*
  Security Group for the cluster
  */
  source = "emyller/security-group/aws"
  version = "~> 1.0"

  name = "docdb-${var.name}"
  vpc_id = var.vpc_id
  ingress_security_groups = {
    for name, security_group_id in var.ingress_security_groups:
    (name) => {
      protocol = "tcp"
      port = aws_docdb_cluster.main.port
      security_group_id = security_group_id
    }
  }
}
