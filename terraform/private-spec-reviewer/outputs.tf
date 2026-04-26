output "cross_account_role_arn" {
  description = "ARN of the IAM role Baz assumes — configure in Baz dashboard alongside external_id"
  value       = aws_iam_role.cross_account.arn
}

output "runtime_arn" {
  description = "ARN of the AgentCore Runtime — used by Baz to target the correct runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "browser_id" {
  description = "AgentCore Browser identifier — returned by runtime and used by Baz to generate CDP headers"
  value       = aws_bedrockagentcore_browser.this.browser_id
}

output "external_id" {
  description = "Generated external ID — configure in the Baz dashboard alongside the cross-account role ARN"
  value       = random_uuid.external_id.result
  sensitive   = true
}

output "browser_security_group_id" {
  description = "Security group ID for the browser (when VPC mode is enabled)"
  value       = var.enable_vpc ? aws_security_group.browser[0].id : null
}
