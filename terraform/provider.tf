provider "aws" {
  region = var.aws_region
  # insecure = true
}
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}


################################################################################
# EKS Required Providers
################################################################################
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  # exec {
  #     api_version = "client.authentication.k8s.io/v1beta1"
  #     command     = "aws"
  #     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  #   }

}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
    # exec {
    #   api_version = "client.authentication.k8s.io/v1beta1"
    #   command     = "aws"
    #   args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    # }
  }

  # # Increase timeout for Helm operations
  # registry_config_path = "~/.config/helm/registry.json"
  # repository_config_path = "~/.config/helm/repositories.yaml"
  # repository_cache = "~/.cache/helm/repository"

  # # The timeout should be set at the provider level, not in a registry block
  # timeout = 900 # 15 minutes in seconds
}
provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   command     = "aws"
  #   args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  # }
}

#versions.tf

terraform {
  #   required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}