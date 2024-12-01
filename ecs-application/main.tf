data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition = data.aws_partition.current.partition
  region = data.aws_region.current.name
  cluster_name = regex("[^/]+$", var.cluster_arn)
}

module "security_group" {
  /*
  The security group for the application
  */
  source = "../security-group"
  name = "ecs-${var.namespace}"
  description = coalesce(var.security_group_description, "${var.namespace} application containers")
  vpc_id = var.vpc_id
  ingress_with_source_security_group_id = var.ingress_security_groups
}
