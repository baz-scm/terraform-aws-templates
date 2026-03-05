resource "aws_ssm_parameter" "username" {
  name = "/baz/spec-reviewer/user"
  type = "SecureString"
  value = "testuser"
}

resource "aws_ssm_parameter" "password" {
  name = "/baz/spec-reviewer/password"
  type = "SecureString"
  value = "TestPassword123!"
}