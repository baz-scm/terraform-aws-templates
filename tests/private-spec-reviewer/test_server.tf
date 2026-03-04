# Test web server for VPC connectivity testing
# This server is only accessible from within the VPC via the browser security group
# AgentCore browser connects to: https://<private-ip>

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "test_server" {
  # checkov:skip=CKV2_AWS_5:Security group is attached to EC2 test instance
  name        = "baz-test-server-sg"
  description = "Security group for test web server - allows HTTPS from browser SG only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from browser security group"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.private_spec_reviewer.browser_security_group_id]
  }

  egress {
    description = "Allow outbound for package updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "baz-test-server-sg"
    Environment = "test"
    Purpose     = "VPC connectivity testing"
  }
}

resource "aws_instance" "test_server" {
  # checkov:skip=CKV_AWS_135:Not using IMDSv2 requirement for test server
  # checkov:skip=CKV_AWS_126:Detailed monitoring not needed for test server
  # checkov:skip=CKV_AWS_8:EBS encryption not critical for ephemeral test server
  # checkov:skip=CKV_AWS_79:No IMDSv1 restriction needed for test server
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.nano"
  subnet_id     = module.vpc.private_subnets[0]

  vpc_security_group_ids = [aws_security_group.test_server.id]

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    username = "testuser"
    password = "TestPassword123!"
  }))

  user_data_replace_on_change = true

  tags = {
    Name        = "baz-spec-review-test-server"
    Environment = "test"
    Purpose     = "VPC connectivity testing"
  }
}
