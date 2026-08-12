# examples/basic
#
# Smallest working call of the module: one hostname, no logs, no analytics.
# This directory is a root module. It is what actually gets planned and applied.

terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

# CloudFront certificates, WAF and log delivery only exist in us-east-1.
provider "aws" {
  alias   = "use1"
  region  = "us-east-1"
  profile = var.profile
}

# The account that owns the Route 53 hosted zone. Set dns_profile to the same
# value as profile if your DNS lives in the same account.
provider "aws" {
  alias   = "r53"
  region  = "us-east-1"
  profile = var.dns_profile
}

module "website" {
  source = "../.."

  providers = {
    aws      = aws
    aws.use1 = aws.use1
    aws.r53  = aws.r53
  }

  environment = var.environment
  project     = var.project
  app         = var.app
  domain      = var.domain
}
