output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.terraform_pipeline.name
}

output "codebuild_plan_project" {
  description = "Name of the CodeBuild project for Terraform plan"
  value       = aws_codebuild_project.terraform_plan.name
}

output "codebuild_apply_project" {
  description = "Name of the CodeBuild project for Terraform apply"
  value       = aws_codebuild_project.terraform_apply.name
}

output "artifacts_bucket" {
  description = "S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.codebuild_artifacts.bucket
}
