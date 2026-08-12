# examples/complete
#
# Everything switched on: extra hostnames, access logs in Parquet, Athena
# queries over them, and a WAF with one managed rule tuned down to count mode.

terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "aws" {
  alias   = "use1"
  region  = "us-east-1"
  profile = var.profile
}

provider "aws" {
  alias   = "r53"
  region  = "us-east-1"
  profile = var.dns_profile
}

module "website" {
  source = "../.."

  providers = {
    aws      = aws
    aws.use1 = aws.use1
    aws.r53  = aws.r53
  }

  environment = var.environment
  project     = var.project
  app         = var.app
  domain      = var.domain

  # Also serve the bare www hostname from the same distribution.
  sub_domains = ["www.${var.domain}"]

  # Europe and North America only: cheaper, and enough for this audience.
  cloudfront_price_class = "PriceClass_100"

  # This site loads its fonts from Google, so the strict default needs widening.
  cloudfront_content_security_policy_directives = [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    "img-src 'self' data:",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
    "upgrade-insecure-requests",
  ]

  # Not ready to commit to the preload list yet.
  cloudfront_hsts = {
    preload = false
  }

  logging = {
    enabled        = true
    retention_days = 90
  }

  analyzing = {
    enabled              = true
    partition_start_year = "2026"
  }

  waf = {
    rate_limit = 1000

    rule_overrides = {
      # Fires on legitimate long query strings, so count instead of block.
      AWSManagedRulesCommonRuleSet = ["SizeRestrictions_QUERYSTRING"]
    }
  }
}
