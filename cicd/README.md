# CI/CD Pipeline for EKS Infrastructure

This directory contains Terraform code to set up a CI/CD pipeline for deploying the EKS infrastructure using AWS CodePipeline and CodeBuild.

## Architecture

The CI/CD pipeline consists of the following components:

1. **AWS CodeCommit** - Source code repository
2. **AWS CodeBuild** - For running Terraform plan and apply
3. **AWS CodePipeline** - Orchestrates the CI/CD workflow
4. **S3 Bucket** - Stores pipeline artifacts
5. **IAM Roles and Policies** - Provides necessary permissions

## Pipeline Workflow

1. **Source Stage**: Pulls code from the CodeCommit repository
2. **Plan Stage**: Runs `terraform plan` to preview changes
3. **Approval Stage**: Manual approval step before applying changes
4. **Apply Stage**: Runs `terraform apply` to deploy infrastructure

## Prerequisites

1. AWS account with appropriate permissions
2. AWS CLI configured with access credentials
3. Terraform (version 1.0.0 or later)
4. CodeCommit repository with your EKS infrastructure code

## Deployment Instructions

1. Create a `terraform.tfvars` file based on the example:


2. Update the values in `terraform.tfvars` with your specific configuration.

3. Initialize Terraform:

```bash
terraform init \
        -backend-config="region=$AWS_REGION" \
        -backend-config="bucket=${account_id}-terraform-state" \
        -backend-config="key=${ENVIRONMENT}/cicd/terraform.tfstate" \
        -backend-config="dynamodb_table=${account_id}-terraform-state-lock"
```

4. Plan the deployment:

```bash
terraform plan
```

5. Apply the configuration:

```bash
terraform apply
```

## Important Notes

- The pipeline uses the `run-terraform.sh` script to deploy the infrastructure
- Environment variables are passed from the pipeline to the build projects
- Manual approval is required before applying changes to the infrastructure
- The CodeBuild projects use the Amazon Linux 2 image with Terraform pre-installed
