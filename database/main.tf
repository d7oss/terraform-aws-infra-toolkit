locals {
  # Whether to use a snapshot to create the database
  is_snapshot_based = var.restore_from_cluster_snapshot_identifier != null
  snapshot = local.is_snapshot_based ? one(data.aws_db_cluster_snapshot.latest.*) : null

  # Engine name
  engine = local.is_snapshot_based ? local.snapshot.engine : var.engine

  # Map RDS engine to the connection URL scheme, e.g. postgres://
  engine_scheme = {
    "aurora-postgresql" = "postgres"
    "aurora-mysql" = "mysql"
  }[local.engine]

  # The cluster, either restored from a snapshot or created from scratch
  db_cluster = one(local.is_snapshot_based ? aws_rds_cluster.restored : aws_rds_cluster.main)

  # Whether to manage the subnet group
  is_managing_subnet_group = var.subnet_ids != null
  subnet_group = one(local.is_managing_subnet_group ? aws_db_subnet_group.managed : data.aws_db_subnet_group.reused)
}

data "aws_db_cluster_snapshot" "latest" {
  /*
  The latest snapshot of the source database
  */
  count = local.is_snapshot_based ? 1 : 0
  db_cluster_snapshot_identifier = var.restore_from_cluster_snapshot_identifier
  most_recent = true
}

resource "random_password" "main" {
  /*
  The master password for the database
  */
  length = 24
  override_special = "<>;()&#!^_-"
}

data "aws_rds_engine_version" "main" {
  /*
  Database engine specs for the requested version
  */
  count = local.is_snapshot_based ? 0 : 1
  engine = var.engine
  version = var.engine_version

  # Prevent deprecated versions
  include_all = false

  filter {
    name = "engine-mode"
    values = ["provisioned"]
  }
}

resource "aws_db_subnet_group" "managed" {
  /*
  The database subnet group — if NOT REUSING one
  */
  count = local.is_managing_subnet_group ? 1 : 0
  name = var.subnet_group_name
  subnet_ids = var.subnet_ids
}

data "aws_db_subnet_group" "reused" {
  /*
  The database subnet group — if REUSING one
  */
  count = local.is_managing_subnet_group ? 0 : 1
  name = var.subnet_group_name
}

resource "aws_rds_cluster" "main" {
  /*
  The database cluster — if NOT RESTORING from a snapshot
  */
  count = local.is_snapshot_based ? 0 : 1
  cluster_identifier = coalesce(var.use_prefix, false) ? null : var.name
  cluster_identifier_prefix = coalesce(var.use_prefix, false) ? var.name : null

  # Engine
  engine = one(data.aws_rds_engine_version.main.*.engine)
  engine_mode = "provisioned"
  engine_version = one(data.aws_rds_engine_version.main.*.version)

  # Database
  database_name = coalesce(var.database_name, "main")
  master_username = coalesce(var.master_username, "master")
  master_password = random_password.main.result

  # Networking
  db_subnet_group_name = local.subnet_group.name
  vpc_security_group_ids = [module.security_group.id]

  # Backup
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window
  skip_final_snapshot = var.skip_final_snapshot

  # Maintenance
  apply_immediately = var.apply_immediately
  preferred_maintenance_window = var.preferred_maintenance_window

  dynamic "serverlessv2_scaling_configuration" {
    /*
    Configuration for Aurora Serverless v2
    */
    for_each = var.acu_max_capacity == null ? [] : [true]
    content {
      min_capacity = var.acu_min_capacity
      max_capacity = var.acu_max_capacity
    }
  }
}

resource "aws_rds_cluster" "restored" {
  /*
  The database cluster — if RESTORING from a snapshot
  */
  count = local.is_snapshot_based ? 1 : 0

  snapshot_identifier = var.restore_from_cluster_snapshot_identifier

  # NOTE: Here use_prefix defaults to true in favor of graceful replacement
  cluster_identifier = coalesce(var.use_prefix, true) ? null : var.name  # Might be intentional
  cluster_identifier_prefix = coalesce(var.use_prefix, true) ? var.name : null

  # Engine
  engine = local.snapshot.engine
  engine_version = local.snapshot.engine_version
  engine_mode = "provisioned"

  # Database
  # database_name = "from-snapshot"
  # master_username = "from-snapshot"
  master_password = random_password.main.result

  # Networking
  db_subnet_group_name = local.subnet_group.name
  vpc_security_group_ids = [module.security_group.id]

  # Backup
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window
  skip_final_snapshot = var.skip_final_snapshot

  # Maintenance
  apply_immediately = var.apply_immediately
  preferred_maintenance_window = var.preferred_maintenance_window

  dynamic "serverlessv2_scaling_configuration" {
    /*
    Configuration for Aurora Serverless v2
    */
    for_each = var.acu_max_capacity == null ? [] : [true]
    content {
      min_capacity = var.acu_min_capacity
      max_capacity = var.acu_max_capacity
    }
  }

  lifecycle {
    # Delete the old cluster when the new one is ready
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_instance" "main" {
  /*
  The database instances — including serverless v2 ones
  */
  count = var.instance_count
  cluster_identifier = local.db_cluster.id
  identifier = "${var.name}-${random_pet.instance_names[count.index].id}"
  instance_class = var.instance_class
  engine = local.db_cluster.engine
  engine_version = local.db_cluster.engine_version
}

resource "random_pet" "instance_names" {
  /*
  Random names for the database instances
  */
  count = var.instance_count
  length = 1
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
      port = local.db_cluster.port
      security_group_id = security_group_id
    }
  }
}
