# Terraform AWS Templates

This repository contains Terraform templates for baz.co customers to deploy infrastructure in their AWS accounts.

## Projects

### Private Spec Reviewer

Located in `private-spec-reviewer/`, this module deploys the infrastructure needed for automated spec review functionality using Amazon Bedrock AgentCore.
It allows customers to avoid sending us the user and password details for their environment, and keep the URLs private.

See `private-spec-reviewer/README.md` for usage instructions.
