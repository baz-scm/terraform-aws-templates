variable "baz_aws_account_id" {
  description = "Baz's AWS account ID — the entire account is trusted, not a specific role"
  type        = string
}

variable "ssm_username_path" {
  description = "SSM parameter path for username — baked into runtime env at deploy time"
  type        = string
}

variable "ssm_password_path" {
  description = "SSM parameter path for password — baked into runtime env at deploy time"
  type        = string
}

variable "handler_image_uri" {
  description = "ECR image URI for the login handler — provided by Baz, deployed by customer"
  type        = string
}

variable "vpc_id" {
  description = "Optional VPC ID for private preview envs. Null = public browser."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Required when vpc_id is set. Private subnets for browser ENIs."
  type        = list(string)
  default     = []
}

variable "preview_env_cidr" {
  description = "Required when vpc_id is set. CIDR for security group egress rule."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "recordings_retention_days" {
  description = "S3 lifecycle retention for browser session recordings."
  type        = number
  default     = 30
}

variable "enable_privatelink" {
  description = "Route AgentCore API calls through a VPC endpoint. Requires vpc_id."
  type        = bool
  default     = false
}
