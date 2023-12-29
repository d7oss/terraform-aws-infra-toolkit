module "security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  vpc_id = var.vpc_id
  name = var.name
  description = coalesce(var.description, var.name)

  ingress_with_source_security_group_id = [
    for name, settings in var.ingress_with_source_security_group_id: {
      description = name
      rule = settings.rule
      source_security_group_id = settings.source_security_group_id
    }
  ]

  ingress_with_cidr_blocks = [
    for name, settings in var.ingress_with_cidr_blocks: {
      description = name
      rule = settings.rule
      cidr_blocks = join(",", settings.cidr_blocks)
    }
  ]

  egress_with_cidr_blocks = [
    {  # Allow all egress
      description = "all-egress"
      rule = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  ingress_with_self = [
    {  # Allow all communication between resources within the same group
      rule = "all-all"
      description = "self"
    },
  ]
}
