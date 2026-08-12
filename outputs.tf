# outputs

output "website_url" {
  description = "Primary HTTPS URL the website is served from."
  value       = "https://${local.primary_alias}"
}

output "cloudfront_aliases" {
  description = "Every hostname served by the distribution: the primary alias plus var.sub_domains."
  value       = aws_cloudfront_distribution.web.aliases
}

output "cloudfront_id" {
  description = "Distribution ID. Required to create cache invalidations from a deployment pipeline."
  value       = aws_cloudfront_distribution.web.id
}

output "cloudfront_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.web.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront-generated domain name of the distribution, in the form dxxxxxxxxxxxxx.cloudfront.net."
  value       = aws_cloudfront_distribution.web.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Route 53 hosted zone ID of the distribution, for callers creating their own alias records."
  value       = aws_cloudfront_distribution.web.hosted_zone_id
}

output "web_bucket_id" {
  description = "Name of the S3 bucket holding the website content. This is where the site must be uploaded."
  value       = aws_s3_bucket.web.id
}

output "web_bucket_arn" {
  description = "ARN of the S3 bucket holding the website content, for callers granting their pipeline write access."
  value       = aws_s3_bucket.web.arn
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate securing the distribution."
  value       = aws_acm_certificate.web.arn
}

output "waf_web_acl_arn" {
  description = "ARN of the web ACL associated with the distribution, or null when WAF is disabled."
  value       = local.web_acl_arn
}

output "logs_bucket_id" {
  description = "Name of the access-log bucket, or null when logging is disabled."
  value       = one(aws_s3_bucket.logs[*].id)
}

output "logs_bucket_arn" {
  description = "ARN of the access-log bucket, or null when logging is disabled."
  value       = one(aws_s3_bucket.logs[*].arn)
}

output "logs_kms_key_arn" {
  description = "ARN of the KMS key encrypting the access logs, or null when logging is disabled."
  value       = one(aws_kms_key.s3_logs[*].arn)
}

output "athena_workgroup_name" {
  description = "Athena workgroup holding the saved log queries, or null when analyzing is disabled."
  value       = one(aws_athena_workgroup.main[*].name)
}

output "glue_table_name" {
  description = "Glue catalog table exposing the access logs, or null when analyzing is disabled."
  value       = one(aws_glue_catalog_table.s3_logs[*].name)
}
