provider "aws" {
  profile = "sandbox"
  region  = "eu-central-1"
}

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "private_spec_reviewer" {
  source = "../../private-spec-reviewer"

  baz_aws_account_id = "647348643223"
  ssm_username_path  = "/bazai/preview/username"
  ssm_password_path  = "/bazai/preview/password"
  handler_image_uri  = "public.ecr.aws/docker/library/python:3.14"
  region             = "eu-central-1"
}
