resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = "baz_spec_login"
  role_arn           = aws_iam_role.runtime.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.handler_image_uri
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  environment_variables = {
    // The data objects verify the SSM parameters exist, and if not give a good deploy time error instead of letting
    // the runtime fail and searching the logs
    SSM_USERNAME_PATH = data.aws_ssm_parameter.username.name
    SSM_PASSWORD_PATH = data.aws_ssm_parameter.password.name
    BROWSER_ID        = aws_bedrockagentcore_browser.this.browser_id
  }

  tags = local.common_tags
}
