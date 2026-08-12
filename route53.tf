#

resource "aws_route53_record" "certificate_validation" {
  provider = aws.r53

  for_each = {
    for dvo in aws_acm_certificate.web.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_route53_record" "cloudfront_a_record" {
  provider = aws.r53

  for_each = aws_cloudfront_distribution.web.aliases

  zone_id = data.aws_route53_zone.domain.zone_id

  name = each.value
  type = "A"

  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_aaaa_record" {
  provider = aws.r53

  for_each = aws_cloudfront_distribution.web.aliases

  zone_id = data.aws_route53_zone.domain.zone_id

  name = each.value
  type = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}