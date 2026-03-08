locals {
  # Merge default Project tag with user-provided tags
  common_tags = merge(
    {
      Project = "BazSpecReview"
    },
    var.tags != null ? var.tags : {}
  )
}

data "aws_ssm_parameter" "username" {
  name = var.ssm_username_path
}

data "aws_ssm_parameter" "password" {
  name = var.ssm_password_path
}
