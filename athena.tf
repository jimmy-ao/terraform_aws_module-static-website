# athena

resource "aws_athena_database" "logs" {
  count = var.analyzing.enabled ? 1 : 0

  name          = local.athena_name
  force_destroy = true

  bucket = one(aws_s3_bucket.logs[*].bucket)

  encryption_configuration {
    encryption_option = "SSE_KMS"
    kms_key           = one(aws_kms_key.s3_logs[*].arn)
  }
}

resource "aws_athena_workgroup" "main" {
  count = length(aws_athena_database.logs)

  name          = replace("${local.env}-ath-${local.region}-${var.app}-workgroup", "-", "_")
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.analyzing.bytes_scanned_cutoff

    result_configuration {
      output_location = "s3://${one(aws_s3_bucket.logs[*].bucket)}/${local.athena_results_prefix}"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = one(aws_kms_key.s3_logs[*].arn)
      }
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${local.env}-ath-${local.region}-${var.app}-workgroup"
    Service = "athena"
  })
}

resource "aws_athena_named_query" "page_views_daily" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "page-views-daily"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "Page views and unique visitors per day, last 30 days."

  query = <<-EOT
    SELECT
      "date",
      COUNT(*)              AS page_views,
      COUNT(DISTINCT c_ip)  AS unique_visitors
    FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
    WHERE ${local.athena_recent}
      AND sc_status = '200'
      AND cs_uri_stem LIKE '%.html'
    GROUP BY "date"
    ORDER BY "date" DESC;
  EOT
}

resource "aws_athena_named_query" "top_pages" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "top-pages"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "Most visited pages, last 30 days."

  query = <<-EOT
    SELECT
      cs_uri_stem AS page,
      COUNT(*)    AS hits
    FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
    WHERE ${local.athena_recent}
      AND sc_status = '200'
    GROUP BY cs_uri_stem
    ORDER BY hits DESC
    LIMIT 20;
  EOT
}

resource "aws_athena_named_query" "traffic_by_country" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "traffic-by-country"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "Requests and data transferred per viewer country, last 30 days."

  query = <<-EOT
    SELECT
      c_country,
      COUNT(*)                                        AS requests,
      SUM(CAST(sc_bytes AS bigint)) / 1024.0 / 1024.0 AS data_transferred_mb
    FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
    WHERE ${local.athena_recent}
    GROUP BY c_country
    ORDER BY requests DESC
    LIMIT 20;
  EOT
}

resource "aws_athena_named_query" "errors" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "error-analysis"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "HTTP errors breakdown, last 30 days."

  query = <<-EOT
    SELECT
      sc_status,
      cs_uri_stem,
      x_edge_result_type,
      COUNT(*) AS occurrences
    FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
    WHERE ${local.athena_recent}
      AND CAST(sc_status AS integer) >= 400
    GROUP BY sc_status, cs_uri_stem, x_edge_result_type
    ORDER BY occurrences DESC
    LIMIT 50;
  EOT
}

resource "aws_athena_named_query" "user_agents" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "traffic-by-user-agent"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "Traffic by browser family, last 30 days."

  query = <<-EOT
    WITH classified AS (
      SELECT
        CASE
          WHEN cs_user_agent LIKE '%bot%' OR cs_user_agent LIKE '%Bot%' THEN 'Bot'
          WHEN cs_user_agent LIKE '%Edg%'                               THEN 'Edge'
          WHEN cs_user_agent LIKE '%Chrome%'                            THEN 'Chrome'
          WHEN cs_user_agent LIKE '%Firefox%'                           THEN 'Firefox'
          WHEN cs_user_agent LIKE '%Safari%'                            THEN 'Safari'
          ELSE 'Other'
        END AS browser
      FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
      WHERE ${local.athena_recent}
    )
    SELECT browser, COUNT(*) AS requests
    FROM classified
    GROUP BY browser
    ORDER BY requests DESC;
  EOT
}

resource "aws_athena_named_query" "referrers" {
  count = length(aws_glue_catalog_table.s3_logs)

  name        = "top-referrers"
  workgroup   = one(aws_athena_workgroup.main[*].name)
  database    = one(aws_athena_database.logs[*].name)
  description = "External referrers, last 30 days."

  query = <<-EOT
    SELECT
      cs_referer AS referrer,
      COUNT(*)   AS visits
    FROM ${one(aws_glue_catalog_table.s3_logs[*].name)}
    WHERE ${local.athena_recent}
      AND cs_referer <> '-'
      AND cs_referer NOT LIKE '%${var.domain}%'
    GROUP BY cs_referer
    ORDER BY visits DESC
    LIMIT 20;
  EOT
}