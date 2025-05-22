# Karpenter auto-discover the subnets to create nodes
resource "aws_ec2_tag" "subnet__karpenter_tags" {
  for_each = toset(data.aws_subnets.compute.ids)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

# Ingress controller to create Internet facing ALBs
resource "aws_ec2_tag" "public_subnet_alb_tags" {
  for_each = toset(data.aws_subnets.public.ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = 1

}

# Ingress controller to create Internal ALbs private
resource "aws_ec2_tag" "private_subnet_alb_tags" {
  for_each = toset(data.aws_subnets.compute.ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = 1

}