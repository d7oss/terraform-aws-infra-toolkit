output "url" {
  value = format("%s://%s:%s@%s:%s/%s", [
    local.engine_scheme,
    local.db_cluster.master_username,
    urlencode(random_password.main.result),
    coalesce(var.hostname, local.db_cluster.endpoint),
    local.db_cluster.port,
    local.db_cluster.database_name,
  ]...)
}

output "hostname" {
  value = local.db_cluster.endpoint
}

output "port" {
  value = local.db_cluster.port
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
  value = local.is_snapshot_based ? local.snapshot.id : null
}
