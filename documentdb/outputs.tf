output "url" {
  value = format("%s://%s:%s@%s:%s?%s", [
    "mongodb",
    aws_docdb_cluster.main.master_username,
    urlencode(random_password.master.result),
    aws_docdb_cluster.main.endpoint,
    aws_docdb_cluster.main.port,
    join("&", [
      "retryWrites=false",  # https://stackoverflow.com/a/65460901/307511
    ])
  ]...)
}

output "host" {
  value = aws_docdb_cluster.main.endpoint
}

output "username" {
  value = aws_docdb_cluster.main.master_username
}

output "password" {
  value = aws_docdb_cluster.main.master_password
}
