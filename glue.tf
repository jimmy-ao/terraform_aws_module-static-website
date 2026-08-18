# glue

resource "aws_glue_catalog_table" "s3_logs" {
  count = length(aws_athena_database.logs)

  database_name = one(aws_athena_database.logs[*].name)
  name          = local.glue_name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "distributionid"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }

  parameters = {
    EXTERNAL       = "TRUE"
    classification = "parquet"

    "projection.enabled"               = "true"
    "projection.distributionid.type"   = "enum"
    "projection.distributionid.values" = aws_cloudfront_distribution.web.id
    "projection.year.type"             = "date"
    "projection.year.format"           = "yyyy"
    "projection.year.range"            = "NOW-1YEARS,NOW"
    "projection.month.type"            = "integer"
    "projection.month.range"           = "1,12"
    "projection.month.digits"          = "2"
    "projection.day.type"              = "integer"
    "projection.day.range"             = "1,31"
    "projection.day.digits"            = "2"
    "projection.hour.type"             = "integer"
    "projection.hour.range"            = "0,23"
    "projection.hour.digits"           = "2"

    "storage.location.template" = "s3://${one(aws_s3_bucket.logs[*].bucket)}/${local.cloudfront_log_root}/distributionid=$${distributionid}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}"
  }

  storage_descriptor {
    location      = "s3://${one(aws_s3_bucket.logs[*].bucket)}/${local.cloudfront_log_root}/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = local.log_columns

      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}