data "aws_iam_policy_document" "runtime_resource_policy" {
  statement {
    sid     = "AllowBazInvoke"
    effect  = "Allow"
    actions = ["bedrock-agentcore:InvokeAgentRuntime"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.baz_aws_account_id}:root"]
    }
  }
}

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
    SSM_USERNAME_PATH = var.ssm_username_path
    SSM_PASSWORD_PATH = var.ssm_password_path
    BROWSER_ID        = aws_bedrockagentcore_browser.this.browser_id
  }
}
