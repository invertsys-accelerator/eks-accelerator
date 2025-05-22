data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# VPC Configuraiotn
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "compute" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Name = "${var.vpc_name}-Compute*"
  }

}

data "aws_subnet" "compute_subnets" {
  for_each = toset(data.aws_subnets.compute.ids)
  id       = each.value
}

data "aws_subnets" "data" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Name = "${var.vpc_name}-Data*"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Name = "${var.vpc_name}-FrontEnd*"
  }
}

data "aws_subnets" "public-a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Name = "${var.vpc_name}-FrontEnd-A"
  }
}

data "aws_subnets" "public-b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    Name = "${var.vpc_name}-FrontEnd-B"
  }
}

# EKS Cluster dependencies
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
