# @baz/pulumi-private-spec-reviewer

Pulumi TypeScript component that deploys the AWS infrastructure for [baz.co](https://baz.co) Private Spec Reviewer. Allows customers to keep preview environment credentials and URLs private — Baz never sees them.

## What gets deployed

- **AgentCore Browser** — isolated Chromium browser running in your AWS account
- **AgentCore Runtime** — container runtime executing the login handler
- **S3 bucket** — encrypted browser session recordings with configurable retention
- **IAM roles** — browser execution, runtime execution, and cross-account access for Baz
- **VPC + PrivateLink** (optional) — routes browser traffic through your private network

## Installation

```bash
npm install @baz/pulumi-private-spec-reviewer
```

Peer dependencies (bring your own versions):

```bash
npm install @pulumi/pulumi @pulumi/aws @pulumi/random
```

## Usage

### Minimal (public network)

```typescript
import { PrivateSpecReviewer } from "@baz/pulumi-private-spec-reviewer";

const reviewer = new PrivateSpecReviewer("reviewer", {
    bazAwsAccountId: "123456789012",   // your Baz account ID
    ssmUsernamePath: "/myapp/username", // SSM path — must exist before deploy
    ssmPasswordPath: "/myapp/password",
});

export const crossAccountRoleArn = reviewer.crossAccountRoleArn;
export const externalId = reviewer.externalId; // sensitive — treat as secret
export const runtimeArn = reviewer.runtimeArn;
export const browserId = reviewer.browserId;
```

### VPC mode (private preview environments)

```typescript
const reviewer = new PrivateSpecReviewer("reviewer", {
    bazAwsAccountId: "123456789012",
    ssmUsernamePath: "/myapp/username",
    ssmPasswordPath: "/myapp/password",
    enableVpc: true,
    vpcId: myVpc.id,
    subnetIds: privateSubnetIds,
    previewEnvCidr: "10.0.0.0/16",
});
```

### VPC + PrivateLink (route AgentCore API calls through VPC endpoint)

```typescript
const reviewer = new PrivateSpecReviewer("reviewer", {
    bazAwsAccountId: "123456789012",
    ssmUsernamePath: "/myapp/username",
    ssmPasswordPath: "/myapp/password",
    enableVpc: true,
    vpcId: myVpc.id,
    subnetIds: privateSubnetIds,
    previewEnvCidr: "10.0.0.0/16",
    enablePrivateLink: true,
});
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `bazAwsAccountId` | `string` | required | Baz's AWS account ID — the entire account is trusted |
| `ssmUsernamePath` | `string` | required | SSM parameter path for the preview env username |
| `ssmPasswordPath` | `string` | required | SSM parameter path for the preview env password |
| `handlerImageUri` | `string` | `public.ecr.aws/r0t2y3g0/private-spec-reviewer-handler:v1` | ECR image for the login handler |
| `enableVpc` | `boolean` | `false` | Enable VPC mode for private preview environments |
| `vpcId` | `string` | — | Required when `enableVpc=true` |
| `subnetIds` | `string[]` | — | Private subnets for browser ENIs. Required when `enableVpc=true` |
| `previewEnvCidr` | `string` | — | CIDR for browser egress rule. Required when `enableVpc=true` |
| `region` | `string` | `us-east-1` | AWS region |
| `recordingsRetentionDays` | `number` | `30` | S3 lifecycle retention for session recordings |
| `enablePrivateLink` | `boolean` | `false` | Route AgentCore API calls through a VPC endpoint. Requires `enableVpc=true` |
| `tags` | `Record<string, string>` | `{}` | Additional tags merged onto all resources |

## Outputs

| Name | Type | Description |
|---|---|---|
| `crossAccountRoleArn` | `Output<string>` | ARN of the IAM role Baz assumes — configure in Baz dashboard |
| `externalId` | `Output<string>` | **Sensitive.** External ID for cross-account trust — configure in Baz dashboard alongside role ARN |
| `runtimeArn` | `Output<string>` | ARN of the AgentCore Runtime |
| `browserId` | `Output<string>` | AgentCore Browser identifier |
| `browserSecurityGroupId` | `Output<string \| undefined>` | Browser security group ID (VPC mode only) |

## After deploying

Configure the following in your Baz dashboard:

1. **Cross-account Role ARN** — value of `crossAccountRoleArn` output
2. **External ID** — value of `externalId` output (treat as a secret)
