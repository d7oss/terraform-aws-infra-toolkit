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

  # Collect all TCP settings from all containers
  http_containers_with_tcp = {
    for name, settings in local.all_http_containers:
    (name) => settings if settings.tcp != null
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

  health_check_grace_period_seconds = each.value.health_check_grace_period_seconds

  container_definitions = merge({
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

      port_mappings = [for port_map in [
        settings.http == null ? null : {
          containerPort = settings.http.port
          hostPort = settings.http.port
          protocol = "tcp"
        },
        settings.tcp == null ? null : {
          containerPort = settings.tcp.container_port
          hostPort = settings.tcp.container_port  # Looks wrong but it's not
          protocol = "tcp"
        },
      ]: port_map if port_map != null]

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

      # Shared volume for file mounts
      mount_points = settings.file_mounts == null ? [] : [
        { containerPath = "/mnt", sourceVolume = "${name}-file-mounter" },
      ]

      # Wait for the files to be mounted before starting the task
      dependencies = settings.file_mounts == null ? [] : [
        { containerName = "${name}-file-mounter", condition = "COMPLETE" },
      ]
    }
  }, {
    # Sidecar container to mount files into the task
    for name, container in each.value.containers: ("${name}-file-mounter") => {
      essential = false
      image = "public.ecr.aws/docker/library/bash:5"
      command = ["-c", join(";", [
        for path, contents in container.file_mounts:
        "echo '${contents}' | base64 -d - | tee ${path}"
      ])]
      mount_points = [  # Shared with the main container
        { containerPath = "/mnt", sourceVolume = "${name}-file-mounter" },
      ]
    }
    if container.file_mounts != null
  })

  volume = {
    for name, settings in each.value.containers: ("${name}-file-mounter") => {
      name = "${name}-file-mounter"
    }
    if settings.file_mounts != null
  }

  load_balancer = merge({
    for name, settings in each.value.containers: ("${name}-http") => {
      target_group_arn = aws_lb_target_group.http_services["${each.key}-${name}"].arn
      container_name = name
      container_port = settings.http.port
    }
    if settings.http != null
  }, {
    for name, settings in each.value.containers: ("${name}-tcp") => {
      target_group_arn = aws_lb_target_group.http_tcp_services["${each.key}-${name}"].arn
      container_name = name
      container_port = settings.tcp.container_port
    }
    if settings.tcp != null
  })

  # Auto scaling
  autoscaling_min_capacity = each.value.autoscaling.min_capacity
  autoscaling_max_capacity = each.value.autoscaling.max_capacity
  desired_count = max(each.value.autoscaling.min_capacity, 1)  # At least one task
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
    Name = "${var.namespace}-${each.key}-http"
  }

  lifecycle {
    create_before_destroy = true
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
      dynamic http_header {
        for_each = each.value.http.listener_rule.headers
        content {
          http_header_name = http_header.key
          values = http_header.value
        }
      }
    }
  }
}

resource "aws_lb_target_group" "http_tcp_services" {
  for_each = local.http_containers_with_tcp

  # AWS imposes a 32 character limit that's too easy to hit, so we use a prefix
  name_prefix = substr(each.value.container_name, 0, 6)

  port = each.value.tcp.container_port
  protocol = "TCP"
  target_type = "ip"
  vpc_id = var.vpc_id
  deregistration_delay = 30
  preserve_client_ip = each.value.tcp.preserve_client_ip

  health_check {
    interval = 30
    unhealthy_threshold = 2
    healthy_threshold = 2
    protocol = "TCP"
    port = "traffic-port"
  }

  tags = {
    Name = "${var.namespace}-${each.key}-tcp"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http_tcp_services" {
  for_each = local.http_containers_with_tcp

  load_balancer_arn = each.value.tcp.load_balancer_arn
  port = each.value.tcp.port
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.http_tcp_services[each.key].arn
  }
}
