output "website_url" {
  description = "URL the site is served from."
  value       = module.website.website_url
}

output "web_bucket_id" {
  description = "Bucket to upload the site content to."
  value       = module.website.web_bucket_id
}

output "cloudfront_id" {
  description = "Distribution ID, for cache invalidations."
  value       = module.website.cloudfront_id
}
