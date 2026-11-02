resource "aws_kms_key" "recordings" {
  description             = "Baz Private Spec Reviewer browser recordings"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.recordings_key.json

  tags = local.common_tags
}

resource "aws_kms_alias" "recordings" {
  name          = "alias/baz-private-spec-reviewer"
  target_key_id = aws_kms_key.recordings.key_id
}

data "aws_iam_policy_document" "recordings_key" {
  # checkov:skip=CKV_AWS_109:Key policy, resource "*" refers to this key
  # checkov:skip=CKV_AWS_111:Key policy, resource "*" refers to this key
  # checkov:skip=CKV_AWS_356:Key policy, resource "*" refers to this key
  statement {
    sid       = "AccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AgentCoreRecordings"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["${aws_s3_bucket.recordings.arn}/*"]
    }
  }
}
