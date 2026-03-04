resource "aws_security_group" "browser" {
  count = var.vpc_id != null ? 1 : 0

  name        = "baz-browser-sg"
  description = "Security group for AgentCore Browser ENIs"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to preview env"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.preview_env_cidr]
  }

  lifecycle {
    precondition {
      condition     = var.preview_env_cidr != null
      error_message = "preview_env_cidr must be set when vpc_id is set."
    }
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "subnet_ids must be non-empty when vpc_id is set."
    }
  }
}

resource "aws_bedrockagentcore_browser" "this" {
  name = "baz_spec_review"

  execution_role_arn = aws_iam_role.browser.arn

  dynamic "network_configuration" {
    for_each = [1]
    content {
      network_mode = var.vpc_id != null ? "VPC" : "PUBLIC"

      dynamic "vpc_config" {
        for_each = var.vpc_id != null ? [1] : []
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
}
