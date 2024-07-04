locals {
  node = aws_elasticache_cluster.main.cache_nodes[0]
}

output "url" {
  value = "redis://${local.node.address}:${local.node.port}/0"
}

output "address" {
  value = local.node.address
}
output "port" {
  value = local.node.port
}
