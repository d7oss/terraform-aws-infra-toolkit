terraform {
  experiments = [ module_variable_optional_attrs ]
}

locals {
  # Normalize the services parameters
  services = {
    for name, service in var.services:
    (name) => merge(service, {  # Default values, if undefined
      full_name = "${var.name}-${name}"
      docker_tag = coalesce(service.docker_tag, "master")
      docker_image_source = coalesce(service.docker_image_source, "ecr")
      env = coalesce(service.env, {})
      secrets = coalesce(service.secrets, {})
      health_check_path = coalesce(service.health_check_path, "/")
      health_check_status_codes = coalesce(service.health_check_status_codes, [200, 301, 302])
      has_cache = service.cache_paths != null
      cache_paths = coalesce(service.cache_paths, [])
      has_www = coalesce(service.redirect_apex_to_www, false)
      hostname_apex = replace(service.hostname, "/^www\\./", "")
      hostname_www = replace(service.hostname, "/^(www\\.)?/", "www.")
      redirect_apex_to_www = coalesce(service.redirect_apex_to_www, false)
      auto_scaling = {
        min_instances = coalesce(service.min_instances, 1)
        max_instances = coalesce(service.max_instances, 1)
        cpu_threshold = service.cpu_threshold
        memory_threshold = service.memory_threshold
      }
    })
  }

  # HTTP services
  http_services = {
    for name, service in local.services:
    (name) => service
    if alltrue([
      service.load_balancer != null,
      service.http_port != null,
      service.hostname != null,
    ])
  }

  # HTTP services with CDN entry
  http_services_with_cache = {
    for name, service in local.http_services:
    (name) => service
    if length(service.cache_paths) != 0
  }

  # Services that run as workers
  worker_services = {
    for name, service in local.services:
    (name) => service
    if alltrue([
      service.load_balancer == null,
      service.http_port == null,
      service.hostname == null,
    ])
  }

  # Canonical TLS certificate
  tls_certificate = (var.manage_tls
    ? module.tls_certificate[0]
    : data.aws_acm_certificate.main[0]
  )

  # Canonical TLS certificate (CDN)
  tls_certificate_cdn = (var.manage_tls
    ? module.tls_certificate_cdn[0]
    : data.aws_acm_certificate.cdn[0]
  )
}

module "ecr" {
  /*
  ECR repository to store Docker images
  */
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.3.0"
  for_each = toset(distinct([
    for name, service in local.services:
    service.docker_image
    if service.docker_image_source == "ecr"
  ]))

  repository_name = each.value
  repository_read_write_access_arns = [data.aws_iam_user.cicd.arn]
  repository_image_scan_on_push = true
  repository_image_tag_mutability = "MUTABLE"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {  # Keep last 30 images only
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus = "any"
          countType = "imageCountMoreThan"
          countNumber = 30
        },
        action = { type = "expire" }
      },
    ]
  })
}

module "ecs_cluster" {
  /*
  ECS cluster for the system
  */
  source = "emyller/ecs-cluster/aws"
  version = "~> 2.0"

  name = var.name
  vpc_id = var.vpc
  use_spot = true
  ingress_security_groups = {
    for sgs in values({
      for name, service in local.http_services:
      (service.load_balancer) => data.aws_security_group.http_load_balancers[name]...  # Grouped by ALB
    }):
    "all-from-${sgs[0].name}" => {  # Allow all ingress traffic from the ALB
      port = 0
      protocol = "TCP"
      security_group_id = sgs[0].id
    }
  }
}

module "ecs_application" {
  /*
  ECS service stack for the site
  */
  source = "emyller/ecs-application/aws"
  version = "~> 4.0"
  depends_on = [module.ecr]

  application_name = var.name
  environment_name = "main"  # TODO: Remove this parameter
  cluster_name = module.ecs_cluster.name
  subnets = data.aws_subnets.private.ids
  security_group_ids = [
    module.ecs_cluster.security_group_id,
  ]
  environment_variables = var.env
  secrets = {
    for secret_name in keys(var.secrets):
    (secret_name) => module.secrets[secret_name].name
  }

  services = merge(
    {  # HTTP services
      for name, service in local.http_services:
      (name) => {
        memory = service.memory
        cpu_units = service.cpu_units
        launch_type = "FARGATE"
        is_spot = true
        command = service.command
        docker = {
          image_name = service.docker_image
          image_tag = service.docker_tag
          source = service.docker_image_source
        }
        http = {
          port = service.http_port
          load_balancer_name = service.load_balancer
          listener_rule = {
            hostnames = (service.has_cache ? null : [service.hostname])
            headers = (service.has_cache ? {"X-App": [service.full_name]} : null)
          }
          health_check = {
            path = service.health_check_path
            status_codes = service.health_check_status_codes
          }
        }
        efs_mounts = try({
          "main": {
            file_system_id = service.file_system.id
            root_directory = service.file_system.root_directory
            mount_path = service.file_system.mount_path
          }
        }, null)
        auto_scaling = service.auto_scaling
      }
    },
    {  # TODO: Workers
      for name, service in local.worker_services:
      (name) => {
        memory = service.memory
        cpu_units = service.cpu_units
        launch_type = "FARGATE"
        is_spot = true
        command = service.command
        docker = {
          image_name = service.docker_image
          image_tag = service.docker_tag
          source = service.docker_image_source
        }
        efs_mounts = try({
          "main": {
            file_system_id = service.file_system.id
            root_directory = service.file_system.root_directory
            mount_path = service.file_system.mount_path
          }
        }, null)
        auto_scaling = service.auto_scaling
      }
    }
  )
}

module "secrets" {
  /*
  Secrets containing sensitive data for all services
  */
  source = "emyller/secret/aws"
  version = "~> 1.0"
  for_each = var.secrets

  name = "/main/${var.name}/${each.key}"
  contents = each.value
}

module "iam_user" {
  /*
  IAM user for the application
  */
  source = "d7oss/iam/aws//user"
  version = "~> 0.0"

  # Only enable if permissions are necessary
  count = var.iam_user_permissions == null ? 0 : 1

  name = var.name
  enable_console = false
  enable_cli = true
  allow = var.iam_user_permissions
}

data "aws_lb" "main" {
  /*
  ALB used in each HTTP service
  */
  for_each = local.http_services
  name = each.value.load_balancer
}

data "aws_lb_listener" "https" {
  /*
  HTTPS listener in the ALB
  */
  for_each = local.http_services
  load_balancer_arn = data.aws_lb.main[each.key].arn
  port = 443
}

resource "aws_lb_listener_rule" "redirect_apex_to_www" {
  /*
  ALB rule to redirect apex domain to www
  */
  for_each = {
    for name, service in local.http_services:
    (name) => service
    if service.redirect_apex_to_www
  }

  listener_arn = data.aws_lb_listener.https[each.key].arn

  condition {
    host_header {
      values = [each.value.hostname_apex]
    }
  }

  action {
    type = "redirect"

    redirect {
      host = each.value.hostname_www
      status_code = "HTTP_301"
    }
  }
}

resource "aws_cloudfront_distribution" "cache" {
  /*
  CDN to speed up / cache / reduce costs of network traffic
  */
  for_each = local.http_services_with_cache

  enabled = true
  aliases = [each.value.hostname]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = local.tls_certificate_cdn.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  default_cache_behavior {  # Disable cache by default
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = each.key
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  dynamic "ordered_cache_behavior" {  # Enable cache in specific paths
    for_each = each.value.cache_paths
    iterator = path
    content {
      path_pattern = path.value
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = each.key
      viewer_protocol_policy = "redirect-to-https"
      cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    }
  }

  origin {  # Match the X-App rule in the ALB
    origin_id = each.key
    domain_name = data.aws_lb.main[each.key].dns_name

    custom_header {
      name = "X-App"
      value = each.value.full_name
    }

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
}

module "dns_alb_alias_records" {
  /*
  DNS A records pointing to the ALBs
  */
  source = "d7oss/route53/aws//record"

  for_each = {
    for name, service in local.http_services:
    (name) => service
    if !service.has_cache || service.redirect_apex_to_www
  }

  zone_id = data.aws_route53_zone.main.id
  type = "A"
  name = each.value.hostname_apex
  alias = {
    name = data.aws_lb.main[each.key].dns_name
    zone_id = data.aws_lb.main[each.key].zone_id
    evaluate_target_health = true
  }
}

module "dns_alb_alias_records_www" {
  /*
  DNS A records pointing to the ALBs (www variant)
  */
  source = "d7oss/route53/aws//record"

  for_each = {
    for name, service in local.http_services:
    (name) => service
    if !service.has_cache && service.redirect_apex_to_www
  }

  zone_id = data.aws_route53_zone.main.id
  type = "A"
  name = each.value.hostname_www
  alias = {
    name = data.aws_lb.main[each.key].dns_name
    zone_id = data.aws_lb.main[each.key].zone_id
    evaluate_target_health = true
  }
}

module "dns_cdn_alias_records" {
  /*
  DNS A records pointing to the CDNs
  */
  source = "d7oss/route53/aws//record"

  for_each = local.http_services_with_cache

  zone_id = data.aws_route53_zone.main.id
  type = "A"
  name = each.value.hostname
  alias = {
    name = aws_cloudfront_distribution.cache[each.key].domain_name
    zone_id = aws_cloudfront_distribution.cache[each.key].hosted_zone_id
    evaluate_target_health = true
  }
}

module "tls_certificate" {
  /*
  TLS certificate, if managed
  */
  source = "../tls-certificate"
  count = var.manage_tls ? 1 : 0

  domain_name = var.certificate_domain
  zone_id = data.aws_route53_zone.main.id
}

module "tls_certificate_cdn" {
  /*
  TLS certificate, if managed (CDN)
  */
  source = "../tls-certificate"
  count = var.manage_tls ? 1 : 0
  providers = { aws = aws.use1 }

  domain_name = var.certificate_domain
  zone_id = data.aws_route53_zone.main.id
}
