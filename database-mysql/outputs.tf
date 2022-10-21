output "url" {
  value = format("mysql://%s:%s@%s:%s/%s", [
    aws_rds_cluster.main.master_username,
    urlencode(random_password.main.result),
    aws_rds_cluster.main.endpoint,
    aws_rds_cluster.main.port,
    aws_rds_cluster.main.database_name,
  ]...)
}

output "host" {
  value = aws_rds_cluster.main.endpoint
}

output "username" {
  value = aws_rds_cluster.main.master_username
}

output "password" {
  value = aws_rds_cluster.main.master_password
}

output "name" {
 value = aws_rds_cluster.main.database_name
}
