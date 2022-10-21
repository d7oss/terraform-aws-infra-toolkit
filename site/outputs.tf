output "security_group_id" {
  value = module.ecs_cluster.security_group_id
}

output "iam_user" {
  value = one(module.iam_user)
}
