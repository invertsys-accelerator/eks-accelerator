#################
# AWS EBS CSI
# AWS Load Blancer 
# Metric Server
# Cloudwatch metrics
# External DNS
# Cert Manager
#flunet bit for logs
# Secrets Manager
# Argocd
#####################
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [module.eks]
  create_duration = "30s"
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  # wait for eks cluster
  depends_on = [
    module.eks,
    time_sleep.wait_for_cluster
  ]
  # EKS Managed Add-on
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      set = [
        {
          name  = "nodeSelector.workload"
          value = "system"
        }
      ]
    }
  }

  # AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.lb_irsa_role.iam_role_arn
      },
      {
        name  = "nodeSelector.workload"
        value = "system"
      }
    ]
  }

  # Metrics Server
  enable_metrics_server = true
  metrics_server = {
    values = [<<-EOT
    nodeSelector:
      workload: system
    args:
      - --kubelet-insecure-tls
    EOT
    ]
  }


  # AWS CloudWatch Metrics
  enable_aws_cloudwatch_metrics = true
  aws_cloudwatch_metrics = {
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.cloudwatch_irsa_role.iam_role_arn
      },
      {
        name  = "nodeSelector.workload"
        value = "system"
      }
    ]
  }

  # External DNS
  enable_external_dns = true
  external_dns = {
    namespace = "kube-system"
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.external_dns_irsa_role.iam_role_arn
      },
      {
        name  = "domainFilters[0]"
        value = var.domain # Make sure to define this variable
      },
      {
        name  = "nodeSelector.workload"
        value = "system"
      }
    ]
  }

  # Cert Manager
  enable_cert_manager = true
  cert_manager = {
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.cert_manager_irsa_role.iam_role_arn
      },
      {
        name  = "nodeSelector.workload"
        value = "system"
      }
    ]
  }
  # Fluent Bit
  enable_aws_for_fluentbit = true
  aws_for_fluentbit = {
    values = [<<-EOT
      nodeSelector:
        workload: system
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.fluent_bit_irsa_role.iam_role_arn}
      
      cloudWatch:
        enabled: true
        region: "${var.aws_region}"
        logGroupName: "/aws/eks/${var.cluster_name}/fluentbit-logs"
        logGroupTemplate: "/aws/eks/${var.cluster_name}/@kubernetes/@namespace/@container"
        logStreamPrefix: "fluentbit"
        
      firehose:
        enabled: false
        
      kinesis:
        enabled: false
        
      elasticsearch:
        enabled: false
        
      additionalOutputs: ""
    EOT
    ]
  }
  # Secrets Store CSI Driver
  enable_secrets_store_csi_driver = true
  secrets_store_csi_driver = {
    values = [<<-EOT
      nodeSelector:
        workload: system
      syncSecret:
        enabled: true
      enableSecretRotation: true
      rotationPollInterval: "3600s"
    EOT
    ]
  }

  # AWS Provider for Secrets Store CSI Driver
  enable_secrets_store_csi_driver_provider_aws = true
  secrets_store_csi_driver_provider_aws = {
    values = [<<-EOT
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.secrets_store_csi_driver_irsa_role.iam_role_arn}
    EOT
    ]
  }

  # ArgocD Addons Condifuration
  enable_argocd = true
  argocd = {
    name          = "argocd"
    chart         = "argo-cd"
    repository    = "https://argoproj.github.io/argo-helm"
    namespace     = "argocd"
    chart_version = "8.0.14"
    
    values = [
      <<-EOT
      global:
        domain: null # argocd.example.com
      server:
        service:
          type: ClusterIP
        
        ingress:
          enabled: true
          ingressClassName: alb
          hosts: null
          hostanme: null # argocd.example.com
          rules:
            - http:
                paths:
                  - path: /*
                    pathType: Prefix
                    backend:
                      service:
                        name: argocd-argocd-server
                        port:
                          number: 443
          annotations:
            kubernetes.io/ingress.class: alb
            alb.ingress.kubernetes.io/scheme: internet-facing
            alb.ingress.kubernetes.io/target-type: ip
            alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
            alb.ingress.kubernetes.io/security-groups: ${aws_security_group.argocd_alb.id}
            alb.ingress.kubernetes.io/backend-protocol: HTTP
            alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
            alb.ingress.kubernetes.io/healthcheck-port: "8080"
            alb.ingress.kubernetes.io/healthcheck-path: /
            alb.ingress.kubernetes.io/tags: web-acl=internal,environment=prod,scope=regional
            alb.ingress.kubernetes.io/conditions.hosts: ""
            # alb.ingress.kubernetes.io/certificate-arn: <arn>
            # alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
        configEnabled: true
        name: argocd-server
        
        extraArgs:
          - --insecure
        
        serviceAccount:
          annotations:
            eks.amazonaws.com/role-arn: ${module.argocd_irsa_role.iam_role_arn}
        
        nodeSelector:
          workload: system

      repoServer:
        serviceAccount:
          annotations:
            eks.amazonaws.com/role-arn: ${module.argocd_irsa_role.iam_role_arn}

      controller:
        args:
          appResyncPeriod: "30"
          repoServerTimeoutSeconds: "15"
      EOT
    ]
  }
}


# irsa_roles.tf
# EBS CSI IRSA
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

}

# Load Balancer IRSA
module "lb_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name                              = "${var.cluster_name}-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }

}

# Cloudwatch IRSA
module "cloudwatch_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-cloudwatch"
  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:aws-cloudwatch-metrics"]
    }
  }


}
# external DNS IRSA
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-external-dns"
  # role_policy_arns = {
  #   external_dns = aws_iam_policy.external_dns.arn
  # }
  attach_external_dns_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns-sa"]
    }
  }

}
# cert Manager IRSA
module "cert_manager_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-cert-manager"

  role_policy_arns = {
    cert_manager = aws_iam_policy.cert_manager.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }


}

# Create policy for cert-manager
resource "aws_iam_policy" "cert_manager" {
  name        = "${var.cluster_name}-cert-manager"
  description = "Policy for cert-manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName",
          "route53:ListHostedZones"
        ]
        Resource = ["*"]
      }
    ]
  })
}


# EBS CSI IRSA
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = merge(var.tags, var.default_tags)
}

# Fluenti bit irsa role
module "fluent_bit_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-fluent-bit"

  role_policy_arns = {
    CloudWatchPolicy = aws_iam_policy.fluent_bit.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-for-fluent-bit-sa"]
    }
  }
}

# Create IAM policy for Fluent Bit
resource "aws_iam_policy" "fluent_bit" {
  name        = "${var.cluster_name}-fluent-bit"
  description = "IAM policy for Fluent Bit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:PutLogEvents",
          "cloudwatch:CreateLogGroup",
          "cloudwatch:CreateLogStream",
          "cloudwatch:DescribeLogGroups",
          "cloudwatch:DescribeLogStreams",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}


# Create IAM policy for Secrets Store CSI Driver
resource "aws_iam_policy" "secrets_store_csi_driver" {
  name        = "${var.cluster_name}-secrets-store-csi-driver"
  description = "IAM policy for Secrets Store CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Store IRSA
module "secrets_store_csi_driver_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-secrets-store-csi-driver"

  role_policy_arns = {
    secrets_policy = aws_iam_policy.secrets_store_csi_driver.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:secrets-store-csi-driver"]
    }
  }
}


# Explicit External DNS IAM Policy
resource "aws_iam_policy" "external_dns" {
  name        = "${var.cluster_name}-external-dns"
  description = "IAM Policy for External DNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })
}
# Create IRSA role for ArgoCD with CodeCommit access
module "argocd_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-argocd"
  # attach_argocd_policy = true
  role_policy_arns = {
    codecommit = aws_iam_policy.argocd_codecommit.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd-application-controller", "argocd:argocd-server", "argocd:argocd-repo-server"]
    }
  }

}

# Create IAM policy for ArgoCD CodeCommit access
resource "aws_iam_policy" "argocd_codecommit" {
  name        = "${var.cluster_name}-argocd-codecommit"
  description = "IAM policy for ArgoCD CodeCommit access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:BatchGet*",
          "codecommit:BatchDescribe*",
          "codecommit:Get*",
          "codecommit:Describe*",
          "codecommit:List*",
          "codecommit:GitPull",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" : "codecommit.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

}

