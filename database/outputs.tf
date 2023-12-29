locals {
  # Engine name
  engine = (
    local.is_snapshot_based
    ? one(data.aws_db_cluster_snapshot.latest.*.engine)
    : var.engine
  )

  # Map RDS engine to the connection URL scheme, e.g. postgres://
  engine_scheme = {
    "aurora-postgresql" = "postgres"
    "aurora-mysql" = "mysql"
    "mysql" = "mysql"
  }[local.engine]
}

output "url" {
  value = format("%s://%s:%s@%s:%s/%s", [
    local.engine_scheme,
    local.db_cluster.master_username,
    urlencode(random_password.main.result),
    local.db_cluster.endpoint,
    local.db_cluster.port,
    local.db_cluster.database_name,
  ]...)
}

output "host" {
  value = local.db_cluster.endpoint
}

output "username" {
  value = local.db_cluster.master_username
}

output "password" {
  value = local.db_cluster.master_password
}

output "name" {
 value = local.db_cluster.database_name
}

output "restored_from_snapshot" {
  value = local.snapshot_id
}
