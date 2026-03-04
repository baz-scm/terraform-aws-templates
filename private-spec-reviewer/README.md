# Spec Reviewer — Customer Deployment

This module deploys an isolated browser environment in **your** AWS account so Baz can review your application without accessing your credentials.

---

## What you need from Baz

| Item | Description |
|---|---|
| **Baz AWS Account ID** | Required for cross-account role trust |
| **Handler Image URI** | Docker image URI for the runtime |

---

## What you need to set up

### 1. SSM Parameters (Required)

Store your preview environment credentials in SSM Parameter Store:

```bash
aws ssm put-parameter --name "/myapp/staging/username" --value "your-username" --type SecureString
aws ssm put-parameter --name "/myapp/staging/password" --value "your-password" --type SecureString
```

### 2. Basic deployment (public preview environments)

```hcl
module "baz_spec_login" {
  source             = "./customer_spec_login"
  baz_aws_account_id = "<from Baz>"
  handler_image_uri  = "<from Baz>"
  ssm_username_path  = "/myapp/staging/username"
  ssm_password_path  = "/myapp/staging/password"
}

output "cross_account_role_arn" { value = module.baz_spec_login.cross_account_role_arn }
output "runtime_arn"            { value = module.baz_spec_login.runtime_arn }
output "browser_id"             { value = module.baz_spec_login.browser_id }
output "external_id"            { value = module.baz_spec_login.external_id sensitive = true }
```

### 3. VPC mode (optional — for private preview environments)

If your preview environment is only accessible from inside your VPC:

```hcl
module "baz_spec_login" {
  source             = "./customer_spec_login"
  baz_aws_account_id = "<from Baz>"
  handler_image_uri  = "<from Baz>"
  ssm_username_path  = "/myapp/staging/username"
  ssm_password_path  = "/myapp/staging/password"

  # VPC configuration
  vpc_id           = "vpc-0abc123"
  subnet_ids       = ["subnet-0aaa", "subnet-0bbb"]
  preview_env_cidr = "10.0.0.0/16"
}
```

### 4. PrivateLink (optional — for enhanced security)

To route all API calls through a VPC endpoint (requires VPC mode):

```hcl
module "baz_spec_login" {
  # ...all VPC mode variables...
  enable_privatelink = true
}
```

---

## What to share back with Baz

After running `terraform apply`, provide these outputs to Baz:

| Output | Description                                       |
|---|---------------------------------------------------|
| **`cross_account_role_arn`** | IAM role ARN for cross-account access             |
| **`runtime_arn`** | Agentcore function ARN                            |
| **`browser_id`** | Browser resource identifier                       |
| **`external_id`** | Security token for role assumption                |
| **Deployment region** | AWS region where you deployed (e.g., `us-east-1`) |

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                         YOUR AWS ACCOUNT                               │
│                                                                        │
│  ┌──────────────────┐          ┌─────────────────────────────────┐     │
│  │  SSM Parameter   │          │      AgentCore Runtime          │     │
│  │     Store        │◄─────────│  (handler_image_uri)            │     │
│  │                  │  reads   │                                 │     │
│  │  /staging/user   │          │  1. Reads credentials from SSM  │     │
│  │  /staging/pass   │          │  2. Starts browser session      │     │
│  └──────────────────┘          │  3. Logs into preview env       │     │
│                                │  4. Returns {browser_id,        │     │
│                                │     session_id}                 │     │
│                                └────────────┬────────────────────┘     │
│                                             │                          │
│                                ┌────────────▼────────────────┐         │
│                                │   AgentCore Browser         │         │
│                                │   (Chromium instance)       │         │
│                                │                             │         │
│                                │   • Public or VPC mode      │         │
│  ┌──────────────────┐          │   • Optional: Private env   │         │
│  │  IAM Cross-      │          │     access via VPC          │         │
│  │  Account Role    │          │   • Stores recordings in S3 │         │
│  │                  │          └─────────────────────────────┘         │
│  │  (external_id)   │                        │                         │
│  └────────┬─────────┘                        │                         │
│           │                                  │                         │
└───────────┼──────────────────────────────────┼─────────────────────────┘
            │                                  │
            │ AssumeRole                       │ CDP Protocol
            │ (with external_id)               │ (browser control)
            │                                  │
┌───────────▼──────────────────────────────────▼─────────────────────────┐
│                        BAZ AWS ACCOUNT                                 │
│                                                                        │
│   1. Assumes cross-account role using external_id                      │
│   2. Invokes Bedrock Agentcore runtime                                 │
│   3. Receives {browser_id, session_id}                                 │
│   4. Connects to browser via CDP to review your application            │
│                                                                        │
│   ⚠️  Credentials NEVER leave your account                             │
└────────────────────────────────────────────────────────────────────────┘
```

### What gets deployed:

- **AgentCore Runtime**: Fetches credentials from SSM, starts browser, performs login
- **AgentCore Browser**: Isolated Chromium instance (public or in your VPC)
- **IAM Role**: Cross-account role with external_id for secure access
- **S3 Bucket**: Stores session recordings
- **VPC Resources** (optional): Security groups for private access
- **PrivateLink Endpoint** (optional): VPC interface endpoint for API calls
