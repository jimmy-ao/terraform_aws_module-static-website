# s3 logging

resource "aws_s3_bucket" "logs" {
  count = var.logging.enabled ? 1 : 0

  bucket = "${local.bucket_name}-logs"

  force_destroy = false

  tags = merge(local.common_tags, {
    Name    = "${local.bucket_name}-logs"
    Service = "s3"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = length(aws_s3_bucket.logs)

  bucket = one(aws_s3_bucket.logs[*].id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count = length(aws_s3_bucket.logs)

  bucket = one(aws_s3_bucket.logs[*].id)

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = length(aws_s3_bucket.logs)

  bucket = one(aws_s3_bucket.logs[*].id)

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = local.cloudfront_log_prefix
    }

    expiration {
      days = var.logging.retention_days
    }
  }

  rule {
    id     = "delete-old-athena-results"
    status = "Enabled"

    filter {
      prefix = local.athena_results_prefix
    }

    expiration {
      days = var.analyzing.results_retention_days
    }
  }

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = length(aws_s3_bucket.logs)

  bucket = one(aws_s3_bucket.logs[*].id)

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = one(aws_kms_key.s3_logs[*].arn)
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled       = true
    blocked_encryption_types = ["SSE-C"]
  }
}

resource "aws_s3_bucket_policy" "logs" {
  count = length(aws_s3_bucket.logs)

  bucket = one(aws_s3_bucket.logs[*].id)
  policy = one(data.aws_iam_policy_document.s3_logs[*].json)
}