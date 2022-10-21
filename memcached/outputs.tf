locals {
  node = aws_elasticache_cluster.main.cache_nodes[0]
}

output "url" {
  value = "${local.node.address}:${local.node.port}"
}
