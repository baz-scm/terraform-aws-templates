resource "aws_security_group" "browser" {
  # checkov:skip=CKV2_AWS_5:Security group is attached to aws_bedrockagentcore_browser resource
  count = var.enable_vpc ? 1 : 0

  name        = "baz-browser-tool-sg"
  description = "Security group for AgentCore Browser ENIs"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to preview env"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.preview_env_cidr]
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = !var.enable_vpc || var.vpc_id != null
      error_message = "vpc_id must be set when enable_vpc is true."
    }
    precondition {
      condition     = !var.enable_vpc || var.preview_env_cidr != null
      error_message = "preview_env_cidr must be set when enable_vpc is true."
    }
    precondition {
      condition     = !var.enable_vpc || length(var.subnet_ids) > 0
      error_message = "subnet_ids must be non-empty when enable_vpc is true."
    }
  }
}

resource "aws_bedrockagentcore_browser" "this" {
  name = "baz_spec_review"

  execution_role_arn = aws_iam_role.browser.arn

  dynamic "network_configuration" {
    for_each = [1]
    content {
      network_mode = var.enable_vpc ? "VPC" : "PUBLIC"

      dynamic "vpc_config" {
        for_each = var.enable_vpc ? [1] : []
        content {
          subnets         = var.subnet_ids
          security_groups = [aws_security_group.browser[0].id]
        }
      }
    }
  }

  recording {
    enabled = true
    s3_location {
      bucket = aws_s3_bucket.recordings.bucket
      prefix = "browser-recordings/"
    }
  }

  tags = local.common_tags
}
