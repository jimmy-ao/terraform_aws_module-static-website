# Account-specific values have no defaults on purpose: Terraform will ask for
# them, or read them from a terraform.tfvars you keep locally. That way nobody
# applies this example against the wrong account by accident.

variable "profile" {
  type        = string
  description = "AWS CLI profile for the account hosting the website."
}

variable "dns_profile" {
  type        = string
  description = "AWS CLI profile for the account owning the Route 53 hosted zone. Often the same as profile."
}

variable "domain" {
  type        = string
  description = "Apex domain of an existing Route 53 public hosted zone you control."
}

variable "region" {
  type        = string
  description = "Region for the regional resources."
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Environment code."
  default     = "sbx"
}

variable "project" {
  type        = string
  description = "Project name, used for tagging."
  default     = "static-website"
}

variable "app" {
  type        = string
  description = "Application name. Also the first label of the hostname."
  default     = "demo"
}
