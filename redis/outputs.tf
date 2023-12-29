output "users" {
  value = {
    for user_name in keys(merge(local.default_users, var.extra_users)):
    (user_name) => {
      username = "${var.name}-${user_name}"
      password = random_password.main[user_name].result
    }
  }
}

output "hostname" {
  value = module.redis_cluster.cluster_endpoint_address
}

output "port" {
  value = module.redis_cluster.cluster_endpoint_port
}

output "urls" {
  value = {
    for user_name in keys(merge(local.default_users, var.extra_users)):
    (user_name) => format("redis://%s:%s@%s:%s", [
      "${var.name}-${user_name}",
      urlencode(random_password.main[user_name].result),
      module.redis_cluster.cluster_endpoint_address,
      module.redis_cluster.cluster_endpoint_port,
    ]...)
  }
}
