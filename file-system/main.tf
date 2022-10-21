resource "aws_efs_file_system" "main" {
  /*
  The file system
  */
  creation_token = var.name
  tags = {
    Name = var.name
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
}

resource "aws_efs_mount_target" "main" {
  /*
  Mount targets in the network
  */
  count = 2  # 2 subnets

  file_system_id = aws_efs_file_system.main.id
  subnet_id = data.aws_subnets.private.ids[count.index]
  security_groups = [module.security_group.id]
}

module "security_group" {
  /*
  Security Group for the Elastic Search domain
  */
  source = "emyller/security-group/aws"
  version = "~> 1.0"

  name = "es-${var.name}"
  vpc_id = var.vpc
  ingress_security_groups = {
    for name, security_group_id in var.ingress_security_groups:
    (name) => {
      protocol = "tcp"
      port = 2049
      security_group_id = security_group_id
    }
  }
}
