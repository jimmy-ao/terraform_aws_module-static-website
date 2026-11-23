# main.tf

resource "random_id" "suffix" {
  byte_length = 4
}

resource "terraform_data" "invalidate" {
  triggers_replace = [timestamp()]
}
