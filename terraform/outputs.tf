
output "karpenter_node_iam_role_arn" {
  description = "ARN of IAM role for Karpenter node"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of IAM role for Karpenter node"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Name of SQS queue for Karpenter"
  value       = module.karpenter.queue_name
}

output "karpenter_instance_profile_name" {
  description = "Name of the instance profile for Karpenter nodes"
  value       = module.karpenter.instance_profile_name
}

output "karpenter_service_account" {
  description = "Name of the Kubernetes service account for Karpenter"
  value       = module.karpenter.service_account
}
