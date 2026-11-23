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

resource "aws_cloudfront_function" "index_rewrite" {
  count = var.cloudfront_directory_index_rewrite ? 1 : 0

  name    = "${local.cf_oac_name}-index"
  runtime = "cloudfront-js-2.0"
  comment = "Map directory URIs to index.html for ${var.app}."
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (uri.split('/').pop().indexOf('.') === -1) {
        request.uri = uri + '/index.html';
      }
      return request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "web" {
  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = local.bucket_name
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  dynamic "origin" {
    for_each = var.cloudfront_additional_origins

    content {
      origin_id                = origin.key
      domain_name              = origin.value.domain_name
      origin_path              = origin.value.origin_path
      origin_access_control_id = origin.value.type == "s3" ? aws_cloudfront_origin_access_control.web.id : null

      dynamic "custom_origin_config" {
        for_each = origin.value.type == "http" ? [1] : []

        content {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    }
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

    dynamic "function_association" {
      for_each = var.cloudfront_directory_index_rewrite ? [1] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.index_rewrite[0].arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.cloudfront_ordered_cache_behaviors

    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      target_origin_id = ordered_cache_behavior.value.origin
      allowed_methods  = ordered_cache_behavior.value.allowed_methods
      cached_methods   = ordered_cache_behavior.value.cached_methods

      cache_policy_id            = coalesce(ordered_cache_behavior.value.cache_policy_id, data.aws_cloudfront_cache_policy.caching_optimized.id)
      origin_request_policy_id   = ordered_cache_behavior.value.origin_request_policy_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.web.id

      viewer_protocol_policy = var.cloudfront_protocol_policy
      compress               = true

      dynamic "function_association" {
        for_each = var.cloudfront_directory_index_rewrite && ordered_cache_behavior.value.directory_index_rewrite ? [1] : []

        content {
          event_type   = "viewer-request"
          function_arn = aws_cloudfront_function.index_rewrite[0].arn
        }
      }
    }
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

  tags = merge(local.common_tags, {
    Name    = local.cf_oac_name
    Service = "cloudfront"
  })
}
