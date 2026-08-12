# kms

resource "aws_kms_key" "s3_logs" {
  count = length(aws_s3_bucket.logs)

  description             = "KMS key is used to encrypt bucket that store logs."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = one(data.aws_iam_policy_document.kms[*].json)

  tags = merge(local.common_tags, {
    Name    = "${local.env}-kms-${local.region}-${var.app}"
    Service = "kms"
  })
}

resource "aws_kms_alias" "s3_logs" {
  count = length(aws_s3_bucket.logs)

  name          = "alias/${local.env}-kms-${local.region}-${var.app}-logs"
  target_key_id = one(aws_kms_key.s3_logs[*].key_id)

  depends_on = [aws_kms_key.s3_logs]
}