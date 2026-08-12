# locals

locals {
  env         = substr(var.environment, 0, 1)
  region      = join("", [element((split("-", data.aws_region.current.region)), 0), substr(element((split("-", data.aws_region.current.region)), 1), 0, 1), element((split("-", data.aws_region.current.region)), 2)])
  region_use1 = join("", [element((split("-", data.aws_region.use1.region)), 0), substr(element((split("-", data.aws_region.use1.region)), 1), 0, 1), element((split("-", data.aws_region.use1.region)), 2)])

  primary_alias = "${var.app}.${var.domain}"
  aliases       = distinct(concat([local.primary_alias], var.sub_domains))

  bucket_name = join("-", [local.env, "s3", local.region, var.app, random_id.suffix.hex])
  cf_oac_name = join("-", [local.env, "cf", local.region, var.app, random_id.suffix.hex])
  cf_rhp_name = join("-", [local.env, "cf", local.region, var.app, "headers-policy"])

  create_waf  = var.waf.enabled && var.waf.web_acl_arn == null
  waf_name    = join("-", [local.env, "waf", local.region, var.app])
  web_acl_arn = var.waf.enabled ? coalesce(var.waf.web_acl_arn, one(aws_wafv2_web_acl.website[*].arn)) : null

  athena_name = replace(join("_", [local.env, "ath", local.region, var.app]), "-", "_")
  glue_name   = replace(join("_", [local.env, "glu", local.region, var.app, "s3logs_table"]), "-", "_")

  cloudfront_log_prefix = "AWSLogs/"
  cloudfront_log_root   = "AWSLogs/aws-account-id=${data.aws_caller_identity.current.account_id}/CloudFront"
  athena_results_prefix = "AWSAthenaLogs/"

  content_security_policy = length(var.cloudfront_content_security_policy_directives) > 0 ? join("; ", var.cloudfront_content_security_policy_directives) : null

  log_field_types = {
    "date"                        = "string"
    "time"                        = "string"
    "x-edge-location"             = "string"
    "sc-bytes"                    = "bigint"
    "c-ip"                        = "string"
    "cs-method"                   = "string"
    "cs(Host)"                    = "string"
    "cs-uri-stem"                 = "string"
    "sc-status"                   = "int"
    "cs(Referer)"                 = "string"
    "cs(User-Agent)"              = "string"
    "cs-uri-query"                = "string"
    "cs(Cookie)"                  = "string"
    "x-edge-result-type"          = "string"
    "x-edge-request-id"           = "string"
    "x-host-header"               = "string"
    "cs-protocol"                 = "string"
    "cs-bytes"                    = "bigint"
    "time-taken"                  = "double"
    "x-forwarded-for"             = "string"
    "ssl-protocol"                = "string"
    "ssl-cipher"                  = "string"
    "x-edge-response-result-type" = "string"
    "cs-protocol-version"         = "string"
    "fle-status"                  = "string"
    "fle-encrypted-fields"        = "int"
    "c-port"                      = "int"
    "time-to-first-byte"          = "double"
    "x-edge-detailed-result-type" = "string"
    "sc-content-type"             = "string"
    "sc-content-len"              = "bigint"
    "sc-range-start"              = "bigint"
    "sc-range-end"                = "bigint"
    "c-country"                   = "string"
    "cache-behavior-path-pattern" = "string"
    "timestamp(ms)"               = "bigint"
    "origin-fbl"                  = "double"
    "origin-lbl"                  = "double"
    "asn"                         = "string"
  }

  log_columns_derived = [
    for field in var.logging.record_fields : {
      name = trim(lower(replace(field, "/[^0-9A-Za-z]+/", "_")), "_")
      type = lookup(local.log_field_types, field, "string")
    }
  ]

  log_columns = var.analyzing.columns != null ? var.analyzing.columns : local.log_columns_derived

  athena_recent = "concat(year, '-', month, '-', day) >= date_format(current_date - interval '30' day, '%Y-%m-%d')"

  common_tags = {
    Environment = var.environment
    Location    = data.aws_region.current.region
    ManagedBy   = "terraform"
    Project     = var.project
    App         = var.app
  }
}