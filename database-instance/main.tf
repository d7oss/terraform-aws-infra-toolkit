locals {
  # Whether to use a snapshot to create the database
  is_snapshot_based = var.restore_from_snapshot_identifier != null
  snapshot = local.is_snapshot_based ? one(data.aws_db_snapshot.latest.*) : null

  # Engine name
  engine = local.is_snapshot_based ? local.snapshot.engine : var.engine

  # The instance, either restored from a snapshot or created from scratch
  db_instance = one(local.is_snapshot_based ? aws_db_instance.restored : aws_db_instance.main)

  # Whether to manage the subnet group
  is_managing_subnet_group = var.subnet_ids != null
  subnet_group = one(local.is_managing_subnet_group ? aws_db_subnet_group.managed : data.aws_db_subnet_group.reused)
}

data "aws_rds_engine_version" "main" {
  /*
  Database engine specs for the requested version
  */
  engine = local.is_snapshot_based ? local.snapshot.engine : var.engine
  version = local.is_snapshot_based ? local.snapshot.engine_version : var.engine_version

  # Prevent deprecated versions
  include_all = false
}

data "aws_db_snapshot" "latest" {
  /*
  The latest snapshot of the source database
  */
  count = local.is_snapshot_based ? 1 : 0
  db_snapshot_identifier = var.restore_from_snapshot_identifier
  most_recent = true
}

data "aws_db_subnet_group" "reused" {
  /*
  The reused DB subnet group
  */
  count = local.is_managing_subnet_group ? 0 : 1
  name = var.subnet_group_name
}

resource "aws_db_subnet_group" "managed" {
  /*
  The managed DB subnet group
  */
  count = local.is_managing_subnet_group ? 1 : 0
  name = var.subnet_group_name
  subnet_ids = var.subnet_ids
}

resource "random_password" "main" {
  /*
  The master password for the database
  */
  length = 24
  override_special = "<>;()&#!^_-"
}

resource "aws_db_parameter_group" "main" {
  name = var.name
  family = data.aws_rds_engine_version.main.parameter_group_family
  description = "${var.name} database settings"

  dynamic "parameter" {
    for_each = var.extra_parameters
    content {
      name = parameter.key
      value = parameter.value
      apply_method = "pending-reboot"
    }
  }
}

resource "aws_db_instance" "main" {
  /*
  The main DB instance resource (IF NOT RESTORED FROM A SNAPSHOT)
  */
  count = local.is_snapshot_based ? 0 : 1

  # Instance settings
  identifier = var.name
  engine = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Database
  db_name = "main"
  username = "master"
  password = random_password.main.result

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Networking
  vpc_security_group_ids = concat([module.security_group.id], var.extra_security_group_ids)
  db_subnet_group_name = local.subnet_group.name
  publicly_accessible = var.publicly_accessible

  # Multi-AZ
  multi_az = var.multi_az

  # Storage
  storage_type = var.storage_type
  allocated_storage = var.allocated_storage

  # Maintenance
  apply_immediately = var.apply_immediately
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  allow_major_version_upgrade = false
  auto_minor_version_upgrade = false

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window = var.backup_window
}

resource "aws_db_instance" "restored" {
  /*
  The main DB instance resource (IF RESTORED FROM A SNAPSHOT)
  */
  count = local.is_snapshot_based ? 1 : 0

  # Database
  password = random_password.main.result

  # Database instance settings
  identifier = var.name
  snapshot_identifier = var.restore_from_snapshot_identifier
  allocated_storage = var.allocated_storage
  instance_class = var.instance_class

  # Networking
  db_subnet_group_name = local.subnet_group.name
  vpc_security_group_ids = concat([module.security_group.id], var.extra_security_group_ids)
  publicly_accessible = var.publicly_accessible

  # Apply settings immediately or during the next maintenance window
  apply_immediately = var.apply_immediately

  # Final snapshot
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
}

module "security_group" {
  /*
  The security group for the database
  */
  source = "../security-group"
  name = "db-${var.name}"
  description = coalesce(var.security_group_description, "${var.name} database")
  vpc_id = var.vpc_id
  ingress_with_source_security_group_id = {
    for name, sg_id in var.ingress_security_groups: (name) => {
      source_security_group_id = sg_id
      rule = "all-all"
    }
  }
}

module "hostname" {
  /*
  Hostname aliasing to the database
  */
  source = "d7oss/route53/aws//record"
  version = "~> 1.0"

  for_each = {
    for name, value in {"rw" = var.hostname}: (name) => value
    if var.hostname != null
  }

  zone_id = var.hostname_zone_id
  type = "CNAME"
  name = each.value
  records = [local.db_instance.address]
  ttl = 30
}
