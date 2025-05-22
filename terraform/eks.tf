module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Endpoint Configuration
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = local.allowed_public_cidrs

  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.compute.ids

  # Enable KMS encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Access Entries Configuration
  access_entries = {
    # Platform Admin Team
    eks-platform-admin = {
      kubernetes_groups = []
      principal_arn     = local.eks_platform_admin

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }


    developers = {
      kubernetes_groups = ["developers"]
      principal_arn     = local.eks_developer_ro

      policy_associations = {
        readonly = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Cluster Security Group Rules
  cluster_security_group_additional_rules = {
    ingress_vpc_private = {
      description = "VPC access to API server"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = local.allowed_public_cidrs
    }
    ingress_nodes_internal = {
      description                = "Node to node communication"
      protocol                   = "tcp"
      from_port                  = 0
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node Security Group Rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_80 = {
      description                   = "Cluster API to node port 80"
      protocol                      = "tcp"
      from_port                     = 80
      to_port                       = 80
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_443 = {
      description                   = "Cluster API to node port 443"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_8080 = {
      description                   = "Cluster API to node port 8080"
      protocol                      = "tcp"
      from_port                     = 8080
      to_port                       = 8080
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_alb_8080 = {
      description = "ALB to node port 8080"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      type        = "ingress"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    system = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]
      labels = {
        "node-type"   = "aws-managed"
        "eks-managed" = "true"
        "workload"    = "system"
        "environment" = var.environment
      }
      taints = [ ]
      min_size     = 2
      max_size     = 3
      desired_size = 2
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            encrypted   = true
            kms_key_id  = aws_kms_key.eks.arn
            volume_size = 100
            volume_type = "gp3"
          }
        }
      }
      iam_policies = [
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      ]
    }
  }

  # Karpenter Tags
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # Cluster Addons
  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
    vpc-cni = {
      addon_version     = "v1.19.2-eksbuild.5"
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Logging Configuration
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = merge(var.tags, var.default_tags)
}
