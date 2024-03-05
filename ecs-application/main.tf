data "aws_region" "current" {}

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
