output "url" {
  value = format("%s://%s:%s@%s:%s/%s", [
    local.engine,
    local.db_instance.username,
    urlencode(random_password.main.result),
    coalesce(var.hostname, local.db_instance.address),
    local.db_instance.port,
    local.db_instance.db_name,
  ]...)
}

output "hostname" {
  value = local.db_instance.address
}

output "port" {
  value = local.db_instance.port
}

output "username" {
  value = local.db_instance.username
}

output "password" {
  value = local.db_instance.password
}

output "name" {
 value = local.db_instance.db_name
}

output "restored_from_snapshot" {
  value = local.is_snapshot_based ? local.snapshot.id : null
}
