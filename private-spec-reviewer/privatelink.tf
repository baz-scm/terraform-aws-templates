data "aws_subnet" "selected" {
  count = var.enable_privatelink && var.vpc_id != null ? length(var.subnet_ids) : 0
  id    = var.subnet_ids[count.index]
}

resource "aws_security_group" "privatelink" {
  count = var.enable_privatelink && var.vpc_id != null ? 1 : 0

  name        = "baz-agentcore-endpoint-sg"
  description = "Security group for AgentCore PrivateLink endpoint ENIs"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = data.aws_subnet.selected[*].cidr_block
  }

  lifecycle {
    precondition {
      condition     = var.vpc_id != null
      error_message = "enable_privatelink requires vpc_id to be set."
    }
  }
}

resource "aws_vpc_endpoint" "agentcore" {
  count = var.enable_privatelink && var.vpc_id != null ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.bedrock-agentcore"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.privatelink[0].id]
  private_dns_enabled = true
}
