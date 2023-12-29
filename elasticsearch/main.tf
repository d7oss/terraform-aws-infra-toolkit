locals {
  hostname = coalesce(var.hostname, aws_elasticsearch_domain.main.endpoint)
  is_multi_az = var.availability_zone_count > 1
  is_public = var.vpc_options_if_private == null
}

resource "random_shuffle" "subnets" {
  /*
  Shuffle subnets for the sake of fairness
  */
  count = local.is_public ? 0 : var.availability_zone_count

  input = var.vpc_options_if_private.subnet_ids
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

resource "random_password" "main" {
  /*
  The master password for the database
  */
  count = var.enable_authentication ? 1 : 0

  length = 24
  override_special = "<>;()&#!^_-"
}

resource "aws_elasticsearch_domain" "main" {
  /*
  The ElasticSearch domain
  */
  depends_on = [aws_iam_service_linked_role.es]

  domain_name = var.name
  elasticsearch_version = var.elasticsearch_version
  access_policies = data.aws_iam_policy_document.access_policy.json

  cluster_config {
    instance_type = var.instance_type
    instance_count = var.instance_count
    zone_awareness_enabled = local.is_multi_az

    dynamic "zone_awareness_config" {
      for_each = local.is_multi_az ? [true] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  dynamic "vpc_options" {
    for_each = local.is_public ? [] : [true]
    content {
      subnet_ids = slice(random_shuffle.subnets.result, 0, var.availability_zone_count)
      security_group_ids = concat(
        [module.security_group.id],
        var.vpc_options_if_private.extra_security_group_ids,
      )
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true

    # When using a custom domain
    custom_endpoint_enabled = var.hostname != null
    custom_endpoint = var.hostname
    custom_endpoint_certificate_arn = var.acm_certificate_arn
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  dynamic "advanced_security_options" {
    for_each = var.enable_authentication ? [true] : []
    content {
      enabled = true
      internal_user_database_enabled = true

      master_user_options {
        master_user_name = var.master_username
        master_user_password = one(random_password.main.*.result)
      }
    }
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
  The security group for the ElasticSearch domain
  */
  count = local.is_public ? 0 : 1

  source = "../security-group"
  name = "es-${var.name}"
  description = "${var.name} ElasticSearch domain"
  vpc_id = var.vpc_options_if_private.vpc_id
  ingress_with_source_security_group_id = {
    for description, security_group_id in var.vpc_options_if_private.ingress_security_groups:
    (description) => {
      rule = "elasticsearch-rest-tcp"
      source_security_group_id = security_group_id
    }
  }
}
