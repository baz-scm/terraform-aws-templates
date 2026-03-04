data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "recordings" {
  # checkov:skip=CKV_AWS_18:no need for access logs
  # checkov:skip=CKV_AWS_144:no need for cross region replication
  # checkov:skip=CKV2_AWS_62:no need for event notification
  # checkov:skip=CKV_AWS_21:no need for versioning
  bucket = "baz-browser-recordings-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  restrict_public_buckets = true
  block_public_policy     = true
  block_public_acls       = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    id     = "expire-recordings"
    status = "Enabled"

    expiration {
      days = var.recordings_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  policy = data.aws_iam_policy_document.recordings_bucket.json
}

data "aws_iam_policy_document" "recordings_bucket" {
  statement {
    sid       = "AllowAgentCoreRecordings"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.recordings.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}
