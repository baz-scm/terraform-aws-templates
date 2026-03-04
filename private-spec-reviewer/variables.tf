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

variable "enable_vpc" {
  description = "Enable VPC mode for private preview envs. When false, uses public browser."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for private preview envs. Required when enable_vpc is true."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Private subnets for browser ENIs. Required when enable_vpc is true."
  type        = list(string)
  default     = []
}

variable "preview_env_cidr" {
  description = "CIDR for security group egress rule. Required when enable_vpc is true."
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

variable "tags" {
  description = "Additional tags to apply to all resources. Will be merged with default Project tag."
  type        = map(string)
  default     = null
}
