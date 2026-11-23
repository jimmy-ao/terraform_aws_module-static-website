# main.tf

resource "random_id" "suffix" {
  byte_length = 4
}

resource "terraform_data" "invalidate" {
  triggers_replace = [timestamp()]

  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.aws_cloudfront_create_invalidation.full]
    }
  }
}
