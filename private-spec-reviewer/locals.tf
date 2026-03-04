locals {
  # Validate that if enable_vpc is true, required VPC parameters are provided
  validate_vpc_config = var.enable_vpc ? (
    var.vpc_id != null &&
    length(var.subnet_ids) > 0 &&
    var.preview_env_cidr != null
  ) : true

  # Merge default Project tag with user-provided tags
  common_tags = merge(
    {
      Project = "BazSpecReview"
    },
    var.tags != null ? var.tags : {}
  )
}
