locals {
  # Collect all containers from worker services
  all_worker_containers = {
    for settings in flatten([
      for service_name, service_settings in var.worker_services: [
        for container_name, container_settings in service_settings.containers:
        merge(container_settings, {
          service_name = service_name
          container_name = container_name
        })
      ]
    ]):
    "${settings.service_name}-${settings.container_name}" => settings
  }
}

module "worker_services" {
  /*
  The worker services running in the application stack
  */
  source = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  for_each = var.worker_services

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
          "awslogs-group": aws_cloudwatch_log_group.worker_services["${each.key}-${name}"].name
          "awslogs-stream-prefix": "ecs",
        },
      }

      essential = true
      readonly_root_filesystem = false
    }
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

resource "aws_cloudwatch_log_group" "worker_services" {
  for_each = local.all_worker_containers

  name = coalesce(
    each.value.log_group_name,
    "/ecs/${var.namespace}/${each.value.service_name}/${each.value.container_name}",
  )
  retention_in_days = each.value.log_group_retention_in_days
}
