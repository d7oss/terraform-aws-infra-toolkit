module "scheduled_tasks" {
  /*
  Scheduled tasks backed by EventBridge + ECS
  */
  source = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  for_each = var.scheduled_tasks

  # NOTE: We only want the task definition
  create_service = false

  name = each.key
  family = "${var.namespace}-${each.key}"
  cluster_arn = var.cluster_arn

  cpu = each.value.cpu
  memory = each.value.memory

  container_definitions = {
    (each.key) = {
      image = each.value.container.image
      command = each.value.container.command

      cpu = each.value.cpu
      memory = each.value.memory

      environment = [
        for name, value in each.value.container.environment_variables: {
          name = name
          value = value
        }
      ]

      secrets = [
        for name, value in each.value.container.secrets: {
          name = name
          valueFrom = value
        }
      ]

      # FIXME: As of 2024-11-30, the log group is not namespaced, which might
      # cause conflicts with other environments of the same application stack
      # in the same AWS account, e.g. /aws/ecs/<service>/<container> — we'll
      # create our own log group for now.
      enable_cloudwatch_logging = false
      create_cloudwatch_log_group = false
      log_configuration = {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": local.region,
          "awslogs-group": aws_cloudwatch_log_group.scheduled_tasks[each.key].name,
          "awslogs-stream-prefix": "ecs",
        },
      }

      essential = true
      readonly_root_filesystem = false
    }
  }

  # Networking
  create_security_group = false
  security_group_ids = concat([module.security_group.id], var.extra_security_group_ids)

  # Permissions for task containers
  enable_execute_command = true  # Enable ECS exec
  tasks_iam_role_name = substr("${var.namespace}-${each.key}", 0, 37)
  tasks_iam_role_statements = each.value.extra_task_iam_statements

  # Permissions for task execution
  task_exec_iam_role_name = substr("${var.namespace}-${each.key}", 0, 37)
  task_exec_secret_arns = distinct(values(each.value.container.secrets))
  task_exec_iam_statements = each.value.extra_task_exec_iam_statements
}

module "scheduled_tasks_schedule" {
  source = "terraform-aws-modules/eventbridge/aws"
  version = "~> 3.0"

  for_each = var.scheduled_tasks

  create_bus = false  # ECS is only supported in the default event bus
  append_rule_postfix = false

  # Permissions for task scheduling
  create_role = true
  role_name = substr("${var.namespace}-${each.key}", 0, 37)
  attach_ecs_policy = true
  ecs_target_arns = [
    module.scheduled_tasks[each.key].task_definition_arn,
    "arn:aws:ecs:${local.region}:${local.account_id}:task/${local.cluster_name}/*",
  ]
  ecs_pass_role_resources = [
    module.scheduled_tasks[each.key].task_exec_iam_role_arn,
    module.scheduled_tasks[each.key].tasks_iam_role_arn,
  ]

  rules = {
    ("${var.namespace}-${each.key}") = {
      description = "${var.namespace}-${each.key}"
      state = "ENABLED"
      schedule_expression = each.value.schedule_expression
    }
  }

  targets = {
    ("${var.namespace}-${each.key}") = [{
      name = each.key
      arn = var.cluster_arn
      attach_role_arn = true

      ecs_target = {
        launch_type = "FARGATE"
        task_count = 1
        task_definition_arn = module.scheduled_tasks[each.key].task_definition_arn
        enable_ecs_managed_tags = true

        network_configuration = {
          assign_public_ip = false
          subnets = var.subnet_ids
          security_groups = concat([module.security_group.id], var.extra_security_group_ids)
        }
      }
    }]
  }
}

resource "aws_cloudwatch_log_group" "scheduled_tasks" {
  for_each = var.scheduled_tasks

  name = coalesce(
    each.value.container.log_group_name,
    "/ecs/${var.namespace}/${each.key}"
  )
  retention_in_days = each.value.container.log_group_retention_in_days
}
