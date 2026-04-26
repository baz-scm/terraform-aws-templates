# AWS IaC Templates

This repository contains infrastructure-as-code templates for baz.co customers to deploy infrastructure in their AWS accounts. Templates are available in both Terraform and Pulumi (TypeScript).

## Projects

### Private Spec Reviewer

Deploys the infrastructure needed for automated spec review functionality using Amazon Bedrock AgentCore. Allows customers to avoid sending credential details and keep preview environment URLs private.

#### Terraform

Located in `terraform/private-spec-reviewer/`. See `terraform/private-spec-reviewer/README.md` for usage instructions.

#### Pulumi (TypeScript)

Located in `pulumi/private-spec-reviewer/`. Published as [`@baz/pulumi-private-spec-reviewer`](https://www.npmjs.com/package/@baz/pulumi-private-spec-reviewer) on npm. See `pulumi/private-spec-reviewer/README.md` for usage instructions.
