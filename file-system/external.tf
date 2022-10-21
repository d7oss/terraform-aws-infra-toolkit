data "aws_subnets" "private" {
  tags = { Tier = "private" }

  filter {
    name = "vpc-id"
    values = [var.vpc]
  }
}
