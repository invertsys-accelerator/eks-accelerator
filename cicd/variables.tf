variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "generic-eks-infra"
}

variable "environment" {
  description = "Environment (e.g., non-prod, prod)"
  type        = string
  default     = "non-prod"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "example"
}

variable "repository_url" {
  description = "URL of the CodeCommit repository"
  type        = string
}

variable "repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
}

variable "branch_name" {
  description = "Branch name to trigger the pipeline"
  type        = string
  default     = "main"
}
