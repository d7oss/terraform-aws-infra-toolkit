locals {
  # Collect all containers from HTTP services
  all_http_containers = {
    for settings in flatten([
      for service_name, service_settings in var.http_services: [
        for container_name, container_settings in service_settings.containers:
        merge(container_settings, {
          service_name = service_name
          container_name = container_name
        })
      ]
    ]):
    "${settings.service_name}-${settings.container_name}" => settings
  }

  # Collect all HTTP settings from all containers
  http_containers_with_http = {
    for name, settings in local.all_http_containers:
    (name) => settings if settings.http != null
  }
}

data "aws_lb_listener" "https" {
  for_each = local.http_containers_with_http
  load_balancer_arn = each.value.http.load_balancer_arn
  port = 443
}

module "http_services" {
  /*
  The HTTP services running in the application stack
  */
  source = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  for_each = var.http_services

  name = each.key
  family = "${var.namespace}-${each.key}"
  cluster_arn = var.cluster_arn

  cpu = each.value.cpu
  memory = each.value.memory

  container_definitions = {
    for name, settings in each.value.containers: (name) => {
      image = settings.image
      command = settings.command

      cpu = settings.cpu
      memory = settings.memory

      environment = [
        for name, value in settings.environment_variables: {
          name = name
          value = value
        }
      ]

      secrets = [
        for name, value in settings.secrets: {
          name = name
          valueFrom = value
        }
      ]

      port_mappings = settings.http == null ? [] : [
        {
          containerPort = settings.http.port
          hostPort = settings.http.port
          protocol = "tcp"
        },
      ]

      health_check = try({
        command = settings.health_check.command
        interval = settings.health_check.interval
        retries = settings.health_check.retries
        startPeriod = settings.health_check.start_period
        timeout = settings.health_check.timeout
      }, {})

      dependencies = settings.depends_on == null ? [] : [
        for name, condition in settings.depends_on: {
          containerName = name
          condition = condition
        }
      ]

      # FIXME: As of 2023-12-28, the log group is not namespaced, which might
      # cause conflicts with other environments of the same application stack
      # in the same AWS account, e.g. /aws/ecs/<service>/<container> — we'll
      # create our own log group for now.
      enable_cloudwatch_logging = false
      create_cloudwatch_log_group = false
      log_configuration = {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": data.aws_region.current.name,
          "awslogs-group": aws_cloudwatch_log_group.http_services["${each.key}-${name}"].name
          "awslogs-stream-prefix": "ecs",
        },
      }

      essential = true
      readonly_root_filesystem = false
    }
  }

  load_balancer = {
    for name, settings in each.value.containers: (name) => {
      target_group_arn = aws_lb_target_group.http_services["${each.key}-${name}"].arn
      container_name = name
      container_port = settings.http.port
    }
    if settings.http != null
  }

  # Auto scaling
  autoscaling_min_capacity = each.value.autoscaling.min_capacity
  autoscaling_max_capacity = each.value.autoscaling.max_capacity
  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value = each.value.autoscaling.cpu_threshold
        scale_in_cooldown = each.value.autoscaling.scale_in_cooldown
        scale_out_cooldown = each.value.autoscaling.scale_out_cooldown
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value = each.value.autoscaling.memory_threshold
        scale_in_cooldown = each.value.autoscaling.scale_in_cooldown
        scale_out_cooldown = each.value.autoscaling.scale_out_cooldown
      }
    }
  }

  # Networking
  subnet_ids = var.subnet_ids
  create_security_group = false
  security_group_ids = concat(
    [module.security_group.id],
    var.extra_security_group_ids,
    each.value.extra_security_group_ids,
  )

  # Permissions for task containers
  enable_execute_command = true  # Enable ECS exec
  tasks_iam_role_name = "${var.namespace}-${each.key}"
  tasks_iam_role_statements = each.value.extra_task_iam_statements

  # Permissions for task execution
  task_exec_iam_role_name = "${var.namespace}-${each.key}"
  task_exec_secret_arns = distinct(values(merge(values(each.value.containers)[*].secrets...)))
  task_exec_iam_statements = each.value.extra_task_exec_iam_statements
}

resource "aws_cloudwatch_log_group" "http_services" {
  for_each = local.all_http_containers

  name = coalesce(
    each.value.log_group_name,
    "/ecs/${var.namespace}/${each.value.service_name}/${each.value.container_name}",
  )
  retention_in_days = each.value.log_group_retention_in_days
}

resource "aws_lb_target_group" "http_services" {
  for_each = local.http_containers_with_http

  # AWS imposes a 32 character limit that's too easy to hit, so we use a prefix
  name_prefix = substr(each.value.container_name, 0, 6)

  port = each.value.http.port
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = var.vpc_id

  health_check {
    path = each.value.http.health_check.path
    port = each.value.http.port
    interval = each.value.http.health_check.interval
    healthy_threshold = each.value.http.health_check.healthy_threshold
    unhealthy_threshold = each.value.http.health_check.unhealthy_threshold
    timeout = each.value.http.health_check.timeout
    matcher = join(",", each.value.http.health_check.status_codes)
  }

  tags = {
    Name = "${var.namespace}-${each.key}"
  }
}

resource "aws_lb_listener_rule" "http_services" {
  for_each = local.http_containers_with_http

  listener_arn = data.aws_lb_listener.https[each.key].arn
  priority = each.value.http.listener_rule.priority

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.http_services[each.key].arn
  }

  dynamic "condition" {  # Match hostnames
    for_each = each.value.http.listener_rule.hostnames != null ? [true] : []
    content {
      host_header {
        values = each.value.http.listener_rule.hostnames
      }
    }
  }

  dynamic "condition" {  # Match paths
    for_each = each.value.http.listener_rule.paths != null ? [true] : []
    content {
      path_pattern {
        values = each.value.http.listener_rule.paths
      }
    }
  }

  dynamic "condition" {  # Match headers
    for_each = each.value.http.listener_rule.headers != null ? [true] : []
    content {
      http_header {
        http_header_name = each.key
        values = each.value.http.listener_rule.headers[each.key]
      }
    }
  }
}
