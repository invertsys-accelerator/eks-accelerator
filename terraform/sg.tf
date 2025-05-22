# Add security group for ArgoCD ALB
resource "aws_security_group" "argocd_alb" {
  name        = "${var.cluster_name}-argocd-alb"
  description = "Security group for ArgoCD ALB"
  vpc_id      = data.aws_vpc.selected.id

  # Allow HTTP from your IP only
  ingress {
    description = "HTTP from my IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.allowed_public_cidrs
  }

  ingress {
    description = "HTTP from my IP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.allowed_public_cidrs
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-argocd-alb"
    },
    var.tags
  )
}