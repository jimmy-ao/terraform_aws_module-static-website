# cloudwatch

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  count    = length(aws_s3_bucket.logs)
  provider = aws.use1

  name         = "${local.env}-cwl-${local.region_use1}-${var.app}-delivery-src"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.web.arn

  tags = merge(local.common_tags, {
    Name    = "${local.env}-cwl-${local.region_use1}-${var.app}-delivery-src"
    Service = "cloudwatchLog"
  })
}

resource "aws_cloudwatch_log_delivery_destination" "s3" {
  count    = length(aws_s3_bucket.logs)
  provider = aws.use1

  name          = "${local.env}-cwl-${local.region_use1}-${var.app}-delivery-dst"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = one(aws_s3_bucket.logs[*].arn)
  }

  tags = merge(local.common_tags, {
    Name    = "${local.env}-cwl-${local.region_use1}-${var.app}-delivery-dst"
    Service = "cloudwatchLog"
  })
}

resource "aws_cloudwatch_log_delivery" "cloudfront_s3" {
  count    = length(aws_s3_bucket.logs)
  provider = aws.use1

  delivery_source_name     = one(aws_cloudwatch_log_delivery_source.cloudfront[*].name)
  delivery_destination_arn = one(aws_cloudwatch_log_delivery_destination.s3[*].arn)

  record_fields = var.logging.record_fields

  s3_delivery_configuration {
    suffix_path = "{distributionid}/{yyyy}/{MM}/{dd}"
    enable_hive_compatible_path = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.env}-cwsrc-${local.region_use1}-${var.app}"
    Service = "cloudwatchLog"
  })

  depends_on = [aws_s3_bucket_policy.logs]
}