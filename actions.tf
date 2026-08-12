# actions

action "aws_cloudfront_create_invalidation" "full" {
  config {
    distribution_id = aws_cloudfront_distribution.web.id
    paths           = ["/*"]
  }
}