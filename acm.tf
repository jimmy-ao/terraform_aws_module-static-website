# aws certificate manager

resource "aws_acm_certificate" "web" {
  provider = aws.use1

  domain_name               = local.primary_alias
  subject_alternative_names = setsubtract(local.aliases, [local.primary_alias])

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = join("-", [local.env, "acm", local.region_use1, var.app])
    Service = "AWSCertificateManager"
  })
}

resource "aws_acm_certificate_validation" "web" {
  provider = aws.use1

  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}



