# Private Spec Reviewer Test Setup

This test environment demonstrates the private-spec-reviewer module with VPC connectivity testing.

## How It Works: End-to-End Flow

### The Complete Authentication Flow

1. **Baz Triggers Runtime Invocation** (Cross-Account)
   - Baz's system assumes the `cross_account` role using the `external_id`
   - Invokes the AgentCore Runtime via `bedrock-agentcore:InvokeAgentRuntime` API
   - This starts the customer's container execution

2. **Customer's Runtime Container Executes**
   - AgentCore Runtime runs the **customer's container** (specified in `handler_image_uri`)
   - Container receives the **target URL** from Baz in the invocation request (dynamic per request)
   - Container has access to customer's environment:
     - Reads username/password from **customer's SSM Parameter Store** (SSM paths configured at deployment time via environment variables, don't change)
     - Has access to customer's VPC resources
   - Container initiates a browser session: `bedrock-agentcore:StartBrowserSession`
   - Gets back a browser session ID and WebSocket endpoint for CDP

3. **Container Controls Browser for Login**
   - Container connects to the browser session via Chrome DevTools Protocol (CDP) over WebSocket
   - Container sends CDP commands to:
     - Navigate to the private test server: `https://<private-ip>` (only accessible in customer VPC)
     - Fill in username and password fields (credentials from customer's SSM)
     - Submit the login form
     - Extract session cookies/tokens after successful login
   - Browser executes in customer's VPC with access to private resources

4. **Browser Session Recording**
   - All browser actions are recorded to the customer's S3 bucket
   - Browser execution role has permissions to write to customer's recordings bucket
   - Recordings stored at: `s3://baz-browser-recordings-<account>/browser-recordings/`

5. **Container Returns Credentials to Baz**
   - After successful login, container extracts session cookies/tokens
   - Container returns these credentials in the InvokeAgentRuntime response
   - Baz receives the credentials and can use them (exact mechanism TBD)

### Key Architecture Points

**Why run in customer's environment?**
- ✓ Credentials never leave customer's AWS account (stored in customer's SSM)
- ✓ Private resources accessible only from customer's VPC
- ✓ Customer controls the login container code
- ✓ Customer can audit all browser sessions via S3 recordings

**How does the container connect to the browser?**
- Container calls `bedrock-agentcore:StartBrowserSession` API
- AWS returns a WebSocket URL for CDP (Chrome DevTools Protocol) connection
- Container uses this WebSocket to send browser automation commands
- AgentCore service routes commands to the browser instance running in customer's VPC

**Environment Variables Available to Customer's Runtime Container:**
```
SSM_USERNAME_PATH = "/bazai/preview/username"  # Path in customer's SSM
SSM_PASSWORD_PATH = "/bazai/preview/password"  # Path in customer's SSM
BROWSER_ID        = "<browser-id>"             # Customer's browser instance
```

**Cross-Account Flow:**
```
Baz System (Account A)
    ↓ AssumeRole(cross_account_role, external_id)
    ↓ InvokeAgentRuntime
Customer's AgentCore Runtime (Account B)
    ↓ Runs customer's container
Customer's Container (Account B)
    ↓ Read SSM (customer's credentials)
    ↓ StartBrowserSession
Customer's AgentCore Browser (Account B, VPC)
    ↓ HTTPS to private IP
Customer's Test Server (Account B, VPC)
    ↓ Return session cookies
Customer's Container (Account B)
    ↓ Return credentials in response
Baz System (Account A)
    ↓ Receives credentials
```

## What's Deployed

### 1. VPC Infrastructure
- **VPC**: 10.0.0.0/16
- **Private Subnets**: 3 subnets across 3 AZs
- **Public Subnets**: 3 subnets across 3 AZs
- **NAT Gateway**: Single NAT gateway for private subnet internet access

### 2. Private Spec Reviewer Module
- **AgentCore Browser**: Deployed in VPC mode with browser security group
- **AgentCore Runtime**: Container-based runtime for spec login automation
- **S3 Bucket**: For browser session recordings
- **IAM Roles**:
  - Browser execution role (S3 write, KMS access)
  - Runtime execution role (SSM read, browser access)
  - Cross-account role for Baz account access
- **PrivateLink**: Optional VPC endpoint for AgentCore API calls

### 3. Test Web Server (VPC Connectivity Testing)
- **Instance Type**: t3.nano (Amazon Linux 2023)
- **Location**: Private subnet (not publicly accessible)
- **Web Server**: Nginx with HTTPS (self-signed certificate)
- **Authentication**: HTTP Basic Auth
- **Security**: Only accessible from browser security group on port 443

## Test Server Details

### Access Information
- **URL**: `https://<private-ip>` (see outputs after deployment)
- **Username**: `testuser`
- **Password**: `TestPassword123!`
- **Port**: 443 (HTTPS)

### What It Tests
When the AgentCore browser successfully connects to the test server, it proves:
- ✓ VPC connectivity is working
- ✓ Security groups are properly configured
- ✓ Private DNS resolution works within VPC
- ✓ HTTPS with basic authentication is functional
- ✓ Browser can access private resources

### Test Page
The server hosts a simple HTML page that displays:
- Success message confirming connection
- List of what the test proves
- Current server time

## Deployment

### Prerequisites
- AWS credentials configured (profile: `sandbox`)
- Terraform >= 1.5
- AWS provider >= 5.0

### Deploy
```bash
cd tests/private-spec-reviewer
terraform init
terraform apply
```

### Important Outputs
After deployment, note these outputs:
- `test_server_url` - HTTPS URL to test connectivity
- `test_server_credentials` - Username and password (sensitive)
- `cross_account_role_arn` - ARN for Baz to assume
- `external_id` - Secret for cross-account role assumption (sensitive)
- `runtime_arn` - AgentCore runtime ARN for Baz

### Test the Connection
1. Get the test server URL from outputs:
   ```bash
   terraform output test_server_url
   ```

2. Configure the AgentCore browser/runtime to navigate to this URL

3. Use the credentials:
   ```bash
   terraform output -json test_server_credentials
   ```

4. If successful, you'll see a green success page

## Network Architecture

```
┌─────────────────────────────────────────────────────┐
│                       VPC                            │
│                                                      │
│  ┌──────────────────┐         ┌──────────────────┐ │
│  │  Private Subnet  │         │  Private Subnet  │ │
│  │                  │         │                  │ │
│  │  ┌────────────┐  │         │  ┌────────────┐  │ │
│  │  │ Test Server│◄─┼─────────┼──┤   Browser  │  │ │
│  │  │   (Nginx)  │  │  HTTPS  │  │  (AgentCore)  │ │
│  │  │  Port 443  │  │  Only   │  │             │  │ │
│  │  └────────────┘  │         │  └────────────┘  │ │
│  │                  │         │                  │ │
│  │  Private IP only │         │  Managed ENIs   │ │
│  └──────────────────┘         └──────────────────┘ │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Security

### Network Isolation
- Test server has NO public IP
- Only accessible via private IP from within VPC
- Security group restricts access to browser security group only

### Authentication
- HTTPS enforced (self-signed cert)
- HTTP Basic Authentication required
- Credentials are test-only (not for production)

## Configuration

The test is configured in `main.tf`:
```hcl
module "private_spec_reviewer" {
  enable_vpc         = true
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  preview_env_cidr   = module.vpc.vpc_cidr_block
  enable_privatelink = true
}
```

## Cleanup

```bash
terraform destroy
```

**Note**: If you encounter issues destroying the AgentCore browser resources, ENIs may need time to detach. Wait a few minutes and retry.

## Troubleshooting

### Browser can't connect to test server
1. Check security group rules: `aws ec2 describe-security-groups`
2. Verify test server is running: Check EC2 console
3. Check nginx status: Connect to instance and run `systemctl status nginx`

### Test server not responding
1. Wait 2-3 minutes after deployment for user_data script to complete
2. Check instance logs in EC2 console
3. Verify the instance is in the correct subnet and has a private IP

### SSL Certificate Errors
The test server uses a self-signed certificate. The browser may need to be configured to accept self-signed certificates for testing purposes.
