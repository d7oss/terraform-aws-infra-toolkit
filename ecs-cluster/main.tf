module "cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  cluster_name = var.name
  fargate_capacity_providers = {
    for name, settings in var.capacity_providers:
    (name) => {
      default_capacity_provider_strategy = settings
    }
  }
}
