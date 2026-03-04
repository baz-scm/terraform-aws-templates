output "cross_account_role_arn" {
  description = "ARN of the IAM role Baz assumes — configure in the Baz dashboard"
  value       = module.private_spec_reviewer.cross_account_role_arn
}

output "runtime_arn" {
  description = "ARN of the AgentCore Runtime"
  value       = module.private_spec_reviewer.runtime_arn
}

output "browser_id" {
  description = "AgentCore Browser Tool ID"
  value       = module.private_spec_reviewer.browser_id
}

output "external_id" {
  description = "Generated external ID - configure in the Baz dashboard alongside the cross-account role ARN"
  value       = module.private_spec_reviewer.external_id
  sensitive   = true
}
