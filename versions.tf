# versions.tf


terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.use1, aws.r53]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
