# waf
resource "aws_wafv2_web_acl" "website" {
  provider = aws.use1

  count = local.create_waf ? 1 : 0

  name        = local.waf_name
  description = "Static website protection for ${var.app}."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.waf.rate_limit != null ? [var.waf.rate_limit] : []

    content {
      name     = "rateLimit"
      priority = 0

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "rateLimit"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = { for index, group in var.waf.managed_rule_groups : group => index }

    content {
      name     = rule.key
      priority = rule.value + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = toset(lookup(var.waf.rule_overrides, rule.key, []))

            content {
              name = rule_action_override.value

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = replace(local.waf_name, "-", "")
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name    = local.waf_name
    Service = "WAF"
  })
}
