# cloudfront

resource "aws_cloudfront_origin_access_control" "web" {
  name = local.cf_oac_name

  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_response_headers_policy" "web" {
  name    = local.cf_rhp_name
  comment = "Security + Geolocation headers for ${var.app}."

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.cloudfront_hsts.max_age_seconds
      include_subdomains         = var.cloudfront_hsts.include_subdomains
      preload                    = var.cloudfront_hsts.preload
      override                   = true
    }

    content_type_options {
      override = true
    }

    dynamic "content_security_policy" {
      for_each = local.content_security_policy != null ? [1] : []

      content {
        override                = true
        content_security_policy = local.content_security_policy
      }
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "accelerometer=(), camera=(), geolocation=(self), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
      override = true
    }

    items {
      header   = "Cross-Origin-Opener-Policy"
      value    = "same-origin"
      override = true
    }

    items {
      header   = "Cross-Origin-Resource-Policy"
      value    = "same-origin"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "web" {
  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = local.bucket_name
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  aliases = local.aliases

  price_class         = var.cloudfront_price_class
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.cloudfront_index_document

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/${var.cloudfront_error_document}"
    error_caching_min_ttl = var.cloudfront_error_caching_min_ttl
  }

  web_acl_id = local.web_acl_arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.bucket_name

    response_headers_policy_id = aws_cloudfront_response_headers_policy.web.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id

    viewer_protocol_policy = var.cloudfront_protocol_policy

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_type
      locations        = var.cloudfront_geo_restriction_locations
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.web.arn
    minimum_protocol_version = var.cloudfront_minimum_protocol_version
    ssl_support_method       = var.cloudfront_ssl_support_method
  }

  lifecycle {
    action_trigger {
      events  = [after_update]
      actions = [action.aws_cloudfront_create_invalidation.full]
    }
  }

  tags = merge(local.common_tags, {
    Name    = local.cf_oac_name
    Service = "cloudfront"
  })
}