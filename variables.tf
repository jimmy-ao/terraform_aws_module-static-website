# variables.tf

variable "environment" {
  type        = string
  description = "Name of the environment these resources belong to."
  nullable    = false

  validation {
    condition     = contains(["prd", "npe", "uat", "lab", "tst", "sbx"], var.environment)
    error_message = "The environment must be one of: prd, npe, uat, lab, tst, sbx."
  }
}

variable "project" {
  type        = string
  description = "Name of the project these resources belong to."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$", var.project))
    error_message = "The project name must contain: lowercase letters, digits and hyphens only, between 3 and 50 characters, and must not start or end with a hyphen."
  }
}

variable "app" {
  type        = string
  description = "Name of the application these resources are provisioned for."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$", var.app))
    error_message = "The app name must contain lowercase letters, digits and hyphens only, be between 3 and 30 characters, and must not start or end with a hyphen."
  }
}

variable "domain" {
  type        = string
  description = "Apex domain of the Route 53 public hosted zone that will hold the DNS records. The zone must already exist: the module looks it up by this name and does not create it. The website itself is served from <app>.<domain>, not from the apex."
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.domain))
    error_message = "The domain must be a valid lowercase apex domain matching an existing Route 53 hosted zone, such as archnops.com."
  }

  validation {
    condition     = length(var.domain) <= 253
    error_message = "The domain must not exceed 253 characters."
  }
}

# acm

variable "sub_domains" {
  type        = list(string)
  description = "Additional hostnames served by the distribution, on top of the primary <app>.<domain>. Each one becomes a subject alternative name on the ACM certificate and gets its own Route 53 alias records, so all of them must sit inside the var.domain hosted zone. Wildcards such as *.example.com are accepted."
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for name in var.sub_domains :
      can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", name))
    ])
    error_message = "Each alternative name must be a valid lowercase FQDN, optionally prefixed with '*.' for a wildcard."
  }

  validation {
    condition = alltrue([
      for name in var.sub_domains :
      name == var.domain || endswith(name, ".${var.domain}")
    ])
    error_message = "Each alternative name must belong to the var.domain hosted zone, since the module creates its Route 53 records there."
  }

  validation {
    condition     = length(var.sub_domains) <= 9
    error_message = "ACM issues certificates for up to 10 names by default, one of which is the primary <app>.<domain>. Request a quota increase before going beyond 9 alternative names."
  }
}

# cloudfront variables

variable "cloudfront_price_class" {
  type        = string
  description = "How many edge locations CloudFront will use for your distribution."
  default     = "PriceClass_All"
  nullable    = false

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "The price class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "cloudfront_protocol_policy" {
  type        = string
  description = "Viewer protocol policy for CloudFront cache behaviors. Only policies that enforce HTTPS are permitted."
  default     = "redirect-to-https"
  nullable    = false

  validation {
    condition     = contains(["https-only", "redirect-to-https"], var.cloudfront_protocol_policy)
    error_message = "Protocol policy must be one either https-only or redirect-to-https."
  }
}

variable "cloudfront_geo_restriction_type" {
  type        = string
  description = "Geographic restriction method applied to the distribution."
  default     = "none"
  nullable    = false

  validation {
    condition     = contains(["blacklist", "whitelist", "none"], var.cloudfront_geo_restriction_type)
    error_message = "The geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "cloudfront_geo_restriction_locations" {
  type        = list(string)
  description = "ISO 3166-1 alpha-2 country codes to allow or deny. Must be empty when the restriction type is none."
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for country in var.cloudfront_geo_restriction_locations : can(regex("^[A-Z]{2}$", country))
    ])
    error_message = "Each location must be an uppercase ISO 3166-1 alpha-2 country code, such as SE or FR."
  }

  validation {
    condition     = (var.cloudfront_geo_restriction_type == "none") == (length(var.cloudfront_geo_restriction_locations) == 0)
    error_message = "Locations must be empty when the restriction type is none, and non-empty otherwise."
  }
}

variable "cloudfront_minimum_protocol_version" {
  type        = string
  description = "Minimum TLS version viewers must support to connect to the distribution."
  default     = "TLSv1.2_2021"
  nullable    = false

  validation {
    condition     = contains(["TLSv1.2_2019", "TLSv1.2_2021"], var.cloudfront_minimum_protocol_version)
    error_message = "The minimum protocol version must be one of: TLSv1.2_2019, TLSv1.2_2021."
  }
}

variable "cloudfront_ssl_support_method" {
  type        = string
  description = "How CloudFront serves HTTPS. sni-only is free; vip provisions dedicated IPs and is billed monthly."
  default     = "sni-only"
  nullable    = false

  validation {
    condition     = contains(["sni-only", "vip"], var.cloudfront_ssl_support_method)
    error_message = "SSL support method must be set with one of these values: sni-only / vip."
  }
}

variable "cloudfront_hsts" {
  type = object({
    max_age_seconds    = optional(number, 31536000)
    include_subdomains = optional(bool, true)
    preload            = optional(bool, true)
  })
  description = "Strict-Transport-Security header settings. Enabling preload is irreversible in practice: removal from the browser preload list takes months, during which plain HTTP fails on the domain and all subdomains."
  default     = {}
  nullable    = false

  validation {
    condition = !var.cloudfront_hsts.preload || (
      var.cloudfront_hsts.include_subdomains &&
      var.cloudfront_hsts.max_age_seconds >= 31536000
    )
    error_message = "HSTS preload requires include_subdomains = true and max_age_seconds of at least 31536000 (one year), as mandated by the browser preload list."
  }
}

variable "cloudfront_content_security_policy_directives" {
  type        = list(string)
  description = "Value of the Content-Security-Policy response header. Set to null to omit the header entirely."
  default = [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "upgrade-insecure-requests",
  ]
  nullable = false

  validation {
    condition = alltrue([
      for directive in var.cloudfront_content_security_policy_directives :
      can(regex("^[a-z-]+( [^;\r\n]+)?$", directive))
    ])
    error_message = "Each directive must start with a lowercase directive name, optionally followed by its values, without semicolons or line breaks."
  }
}

variable "cloudfront_index_document" {
  type        = string
  description = "The name of the index document for the website."
  default     = "index.html"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$", var.cloudfront_index_document))
    error_message = "The index document must be a relative object key such as index.html or app/index.html: letters, digits, dots, underscores and hyphens only, with no leading or trailing slash."
  }

  validation {
    condition     = length(var.cloudfront_index_document) <= 255
    error_message = "The index document must not exceed 255 characters."
  }
}

variable "cloudfront_error_caching_min_ttl" {
  type        = number
  description = "How long, in seconds, CloudFront caches an error response before asking the origin again. Keep it low so that a page you just fixed stops erroring quickly; raise it to shield the origin from repeated requests for something that isn't there."
  default     = 10
  nullable    = false

  validation {
    condition     = var.cloudfront_error_caching_min_ttl >= 0 && var.cloudfront_error_caching_min_ttl <= 31536000
    error_message = "The error caching minimum TTL must be between 0 and 31536000 seconds."
  }
}

variable "cloudfront_error_document" {
  type        = string
  description = "The name of the error document for the website."
  default     = "error.html"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$", var.cloudfront_error_document))
    error_message = "The error document must be a relative object key such as error.html or errors/404.html: letters, digits, dots, underscores and hyphens only, with no leading or trailing slash."
  }

  validation {
    condition     = length(var.cloudfront_error_document) <= 255
    error_message = "The error document must not exceed 255 characters."
  }
}

# logging

variable "logging" {
  type = object({
    enabled        = optional(bool, false)
    retention_days = optional(number, 30)
    record_fields = optional(list(string), [
      "date", "time", "x-edge-location", "sc-bytes", "c-ip", "cs-method",
      "cs(Host)", "cs-uri-stem", "sc-status", "cs(Referer)", "cs(User-Agent)",
      "cs-uri-query", "x-edge-result-type", "x-edge-request-id", "x-host-header",
      "cs-protocol", "cs-bytes", "time-taken", "ssl-protocol", "ssl-cipher",
      "x-edge-response-result-type", "cs-protocol-version",
      "time-to-first-byte", "x-edge-detailed-result-type", "sc-content-type",
      "c-country",
    ])
  })
  description = "CloudFront standard logging (v2) delivered to S3 in Parquet format."
  default     = {}
  nullable    = false
}

# analyzing

variable "analyzing" {
  type = object({
    enabled                = optional(bool, false)
    results_retention_days = optional(number, 7)
    bytes_scanned_cutoff   = optional(number, 10737418240)
    partition_start_year   = optional(string, "2026")

    columns = optional(list(object({
      name = string
      type = string
    })))
  })
  description = "Athena and Glue resources for querying the access logs."
  default     = {}
  nullable    = false

  validation {
    condition     = !var.analyzing.enabled || var.logging.enabled
    error_message = "analyzing.enabled requires logging.enabled: there would be no logs to query."
  }

  validation {
    condition     = var.analyzing.columns == null || length(coalesce(var.analyzing.columns, [])) > 0
    error_message = "analyzing.columns must be null or a non-empty list."
  }
}

# waf

variable "waf" {
  type = object({
    enabled     = optional(bool, true)
    web_acl_arn = optional(string)
    rate_limit  = optional(number, 2000)

    managed_rule_groups = optional(list(string), [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      "AWSManagedRulesAmazonIpReputationList",
    ])

    rule_overrides = optional(map(list(string)), {})
  })
  description = "AWS WAF protection for the distribution. Set web_acl_arn to reuse an existing web ACL instead of creating one."
  default     = {}
  nullable    = false

  validation {
    condition     = var.waf.web_acl_arn == null || var.waf.enabled
    error_message = "waf.web_acl_arn is meaningless when waf.enabled is false."
  }

  validation {
    condition     = var.waf.rate_limit == null || try(var.waf.rate_limit >= 10, false)
    error_message = "waf.rate_limit must be at least 10 requests per 5-minute window, or null to disable the rate-based rule."
  }
}