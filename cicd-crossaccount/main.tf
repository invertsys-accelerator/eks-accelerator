# provider aws
provider "aws" {
  region = var.aws_region
}

# S3 bucket for storing build artifacts
resource "aws_s3_bucket" "codebuild_artifacts" {
  bucket = "${var.project_name}-codebuild-artifacts"

  tags = {
    Name        = "${var.project_name}-codebuild-artifacts"
    Environment = var.environment
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "codebuild_artifacts_versioning" {
  bucket = aws_s3_bucket.codebuild_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}


# CICD Action Role with Admin Access
resource "aws_iam_role" "eks_cicd_action_role" {
  name = "${var.project_name}-eks-cicd-action-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codebuild_role.arn
        }
      }
    ]
  })
}
# IAM policy for CodeBuild
resource "aws_iam_policy" "eks_cicd_policy" {
  name        = "${var.project_name}-eks-cicd-policy"
  description = "Policy for eks cicd"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*",
          "kms:*",
          "autoscaling:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "logs:*",
          "route53:*",
          "acm:*",
          "secretsmanager:*"
        ]
        Resource = "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken",
          "sts:*",
          "cloudformation:CreateStack",
          "sqs:createqueue",
          "events:TagResource",
          "cloudformation:DescribeStacks",
          "sqs:getqueueattributes",
          "events:*",
          "cloudformation:*",
          "sqs:*"
        ],
        "Resource" : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codebuild_artifacts.arn,
          "${aws_s3_bucket.codebuild_artifacts.arn}/*",
          "arn:aws:s3:::${local.account_id}-terraform-state",
          "arn:aws:s3:::${local.account_id}-terraform-state/*"

        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:${local.account_id}-terraform-state-lock", "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.account_id}-terraform-state-lock"]
      }
    ]
  })
}

# Attach AdministratorAccess policy to CICD Action Role
resource "aws_iam_role_policy_attachment" "eks_cicd_admin_policy_attachment" {
  role       = aws_iam_role.eks_cicd_action_role.name
  policy_arn = aws_iam_policy.eks_cicd_policy.arn
}



# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodeBuild
resource "aws_iam_policy" "codebuild_policy" {
  name        = "${var.project_name}-codebuild-policy"
  description = "Policy for CodeBuild to deploy Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "sts:*"
        ]
        Resource = "*"
      },
            {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codebuild_artifacts.arn,
          "${aws_s3_bucket.codebuild_artifacts.arn}/*",
          "arn:aws:s3:::${local.account_id}-terraform-state",
          "arn:aws:s3:::${local.account_id}-terraform-state/*"

        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = ["arn:aws:dynamodb:${var.aws_region}::${local.account_id}-terraform-state-lock", "arn:aws:dynamodb:${var.aws_region}::table/${local.account_id}-terraform-state-lock"]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# CodeBuild project for Terraform plan
resource "aws_codebuild_project" "terraform_plan" {
  name          = "${var.project_name}-terraform-plan"
  description   = "CodeBuild project to run Terraform plan"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "30"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true


    environment_variable {
      name  = "APP_NAME"
      value = var.app_name
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

  }

  source {
    type            = "CODECOMMIT"
    location        = var.repository_url
    git_clone_depth = 1
    buildspec       = "buildspec-plan.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-terraform-plan"
      stream_name = "log-stream"
    }
  }

  tags = {
    Environment = var.environment
  }
}

# CodeBuild project for Terraform apply
resource "aws_codebuild_project" "terraform_apply" {
  name          = "${var.project_name}-terraform-apply"
  description   = "CodeBuild project to run Terraform apply"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "60"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "APP_NAME"
      value = var.app_name
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
     environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
  }

  source {
    type            = "CODECOMMIT"
    location        = var.repository_url
    git_clone_depth = 1
    buildspec       = "buildspec-apply.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-terraform-apply"
      stream_name = "log-stream"
    }
  }

  tags = {
    Environment = var.environment
  }
}


# CodePipeline
resource "aws_codepipeline" "terraform_pipeline" {
  name     = "${var.project_name}-terraform-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codebuild_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName       = var.repository_name
        BranchName           = var.branch_name
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "Terraform-Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
        EnvironmentVariables = jsonencode([
        {
           name  = "ENVIRONMENT"
           value = var.environment
          type  = "PLAINTEXT"
        },
        {
          name  = "ASSUME_ROLE_ARN"
          value = aws_iam_role.eks_cicd_action_role.arn
          type  = "PLAINTEXT"
        } ])
      }
   
    }
  }

  stage {
    name = "Approve"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Apply"

    action {
      name            = "Terraform-Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
        EnvironmentVariables = jsonencode([
        {
           name  = "ENVIRONMENT"
           value = var.environment
          type  = "PLAINTEXT"
        },
        {
          name  = "ASSUME_ROLE_ARN"
          value = aws_iam_role.eks_cicd_action_role.arn
          type  = "PLAINTEXT"
        } ])
      }
      }
    }
  }


# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodePipeline
resource "aws_iam_policy" "codepipeline_policy" {
  name        = "${var.project_name}-codepipeline-policy"
  description = "Policy for CodePipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codebuild_artifacts.arn,
          "${aws_s3_bucket.codebuild_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}
