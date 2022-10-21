resource "random_shuffle" "subnet" {
  /*
  Shuffle subnets for fair choices
  */
  input = data.aws_subnets.private.ids
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "access_policy" {
  statement {
    actions = ["es:*"]
    resources = ["arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.name}/*"]

    principals {
      type = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_elasticsearch_domain" "main" {
  /*
  The ElasticSearch domain
  */
  depends_on = [aws_iam_service_linked_role.es]

  domain_name = var.name
  elasticsearch_version = "2.3"
  access_policies = data.aws_iam_policy_document.access_policy.json

  cluster_config {
    instance_type = "t2.small.elasticsearch"
    instance_count = 1
  }

  vpc_options {
    subnet_ids = [random_shuffle.subnet.result[0]]  # TODO: Support multi-AZ
    security_group_ids = [module.security_group.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }
}

resource "aws_iam_service_linked_role" "es" {
  /*
  Allow ElasticSearch into the VPC
  */
  aws_service_name = "es.amazonaws.com"
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
      port = 443
      security_group_id = security_group_id
    }
  }
}
