resource "random_uuid" "external_id" {}

data "aws_iam_policy_document" "browser_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "browser" {
  name               = "baz-browser-execution"
  assume_role_policy = data.aws_iam_policy_document.browser_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "browser" {
  # checkov:skip=CKV_AWS_356:Using AWS-managed KMS key for S3, ARN not known at plan time
  # checkov:skip=CKV_AWS_111:Write access is scoped to specific S3 bucket, KMS wildcard needed for default encryption
  statement {
    sid    = "S3WriteRecordings"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.recordings.arn}/*"]
  }

  statement {
    sid    = "KMSEncrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "browser" {
  name   = "baz-browser-execution"
  role   = aws_iam_role.browser.id
  policy = data.aws_iam_policy_document.browser.json
}

data "aws_iam_policy_document" "runtime_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runtime" {
  name               = "baz-spec-login-runtime"
  assume_role_policy = data.aws_iam_policy_document.runtime_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "runtime" {
  statement {
    sid       = "SSMGetParameter"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/*"]
  }

  statement {
    sid    = "BrowserSession"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:StartBrowserSession",
      "bedrock-agentcore:GetBrowserSession",
      "bedrock-agentcore:ConnectBrowserAutomationStream",
      "bedrock-agentcore:StopBrowserSession",
    ]
    resources = [aws_bedrockagentcore_browser.this.browser_arn]
  }
}

resource "aws_iam_role_policy" "runtime" {
  name   = "baz-spec-login-runtime"
  role   = aws_iam_role.runtime.id
  policy = data.aws_iam_policy_document.runtime.json
}

data "aws_iam_policy_document" "cross_account_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.baz_aws_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [random_uuid.external_id.result]
    }
  }
}

resource "aws_iam_role" "cross_account" {
  name               = "baz-spec-login-cross-account"
  assume_role_policy = data.aws_iam_policy_document.cross_account_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cross_account" {
  statement {
    sid       = "InvokeRuntime"
    effect    = "Allow"
    actions   = ["bedrock-agentcore:InvokeAgentRuntime"]
    resources = [aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn]
  }

  statement {
    sid       = "ConnectBrowser"
    effect    = "Allow"
    actions   = ["bedrock-agentcore:ConnectBrowserAutomationStream"]
    resources = [aws_bedrockagentcore_browser.this.browser_arn]
  }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "baz-spec-login-cross-account"
  role   = aws_iam_role.cross_account.id
  policy = data.aws_iam_policy_document.cross_account.json
}
