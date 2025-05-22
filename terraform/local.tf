locals {
  createdOn  = formatdate("MM-DD-YYYY hh:mm:ss ", timestamp())
  account_id = data.aws_caller_identity.current.account_id
  aws_region = data.aws_region.current.name
  allowed_public_cidrs    = ["0.0.0.0/0"]
  private_subnet_azs      = [for subnet in data.aws_subnet.compute_subnets : subnet.availability_zone]
  eks_platform_admin      = "arn:aws:iam::${local.account_id}:user/john.doe" # IAM user with eks permission
  eks_developer_ro        = "arn:aws:iam::${local.account_id}:role/eks-ro" $# IAM users role 
}