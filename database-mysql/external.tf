data "aws_subnets" "database" {
  tags = { Tier = "database" }

  filter {
    name = "vpc-id"
    values = [var.vpc]
  }
}
