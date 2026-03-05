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


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "private-spec-reviewer-test-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  single_nat_gateway   = true

  tags = {
    Environment = "test"
    Module      = "private-spec-reviewer"
  }
}

module "private_spec_reviewer" {
  source = "../../private-spec-reviewer"

  baz_aws_account_id = "647348643223"
  ssm_username_path  = aws_ssm_parameter.username.name
  ssm_password_path  = aws_ssm_parameter.password.name
  handler_image_uri  = "public.ecr.aws/docker/library/python:3.14"
  region             = "eu-central-1"

  enable_vpc         = true
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  preview_env_cidr   = module.vpc.vpc_cidr_block
  enable_privatelink = true

  tags = {
    Env = "test"
  }
}
