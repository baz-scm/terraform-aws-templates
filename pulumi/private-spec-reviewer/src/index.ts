import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as random from "@pulumi/random";

export interface PrivateSpecReviewerArgs {
    /** Baz's AWS account ID — the entire account is trusted, not a specific role */
    bazAwsAccountId: pulumi.Input<string>;
    /** SSM parameter path for username — baked into runtime env at deploy time */
    ssmUsernamePath: pulumi.Input<string>;
    /** SSM parameter path for password — baked into runtime env at deploy time */
    ssmPasswordPath: pulumi.Input<string>;
    /** ECR image URI for the login handler — provided by Baz, deployed by customer */
    handlerImageUri?: pulumi.Input<string>;
    /** Enable VPC mode for private preview envs. When false, uses public browser. */
    enableVpc?: boolean;
    /** VPC ID for private preview envs. Required when enableVpc is true. */
    vpcId?: pulumi.Input<string>;
    /** Private subnets for browser ENIs. Required when enableVpc is true. */
    subnetIds?: pulumi.Input<pulumi.Input<string>[]>;
    /** CIDR for security group egress rule. Required when enableVpc is true. */
    previewEnvCidr?: pulumi.Input<string>;
    /** AWS region */
    region?: string;
    /** S3 lifecycle retention for browser session recordings. */
    recordingsRetentionDays?: pulumi.Input<number>;
    /** Route AgentCore API calls through a VPC endpoint. Requires enableVpc. */
    enablePrivateLink?: boolean;
    /** Additional tags applied to all resources. Merged with default Project tag. */
    tags?: pulumi.Input<{ [key: string]: string }>;
}

export class PrivateSpecReviewer extends pulumi.ComponentResource {
    public readonly crossAccountRoleArn: pulumi.Output<string>;
    public readonly runtimeArn: pulumi.Output<string>;
    public readonly browserId: pulumi.Output<string>;
    /** Sensitive — configure in Baz dashboard alongside crossAccountRoleArn */
    public readonly externalId: pulumi.Output<string>;
    /** Defined only when enableVpc=true */
    public readonly browserSecurityGroupId: pulumi.Output<string | undefined>;

    constructor(name: string, args: PrivateSpecReviewerArgs, opts?: pulumi.ComponentResourceOptions) {
        super("baz:index:PrivateSpecReviewer", name, {}, opts);

        // Input validation (replaces Terraform lifecycle.precondition)
        if (args.enableVpc) {
            if (!args.vpcId) throw new Error("vpcId required when enableVpc=true");
            if (!args.previewEnvCidr) throw new Error("previewEnvCidr required when enableVpc=true");
            if (!args.subnetIds) throw new Error("subnetIds required when enableVpc=true");
        }
        if (args.enablePrivateLink && !args.enableVpc) throw new Error("enablePrivateLink requires enableVpc=true");

        const resourceOpts: pulumi.CustomResourceOptions = { parent: this };

        const region = args.region ?? "us-east-1";
        const handlerImageUri = args.handlerImageUri ?? "public.ecr.aws/r0t2y3g0/private-spec-reviewer-handler:v1";
        const recordingsRetentionDays = args.recordingsRetentionDays ?? 30;

        const commonTags = pulumi.output(args.tags ?? {}).apply(t => ({
            Project: "BazSpecReview",
            ...t,
        }));

        // External ID for cross-account trust condition
        const externalIdResource = new random.RandomUuid(`${name}-external-id`, {}, resourceOpts);

        // Account ID for bucket name
        const callerIdentity = aws.getCallerIdentityOutput({}, { parent: this });

        // S3 bucket for browser session recordings
        const recordingsBucket = new aws.s3.Bucket(`${name}-recordings`, {
            bucket: pulumi.interpolate`baz-browser-recordings-${callerIdentity.accountId}`,
            tags: commonTags,
        }, resourceOpts);

        new aws.s3.BucketPublicAccessBlock(`${name}-recordings-pab`, {
            bucket: recordingsBucket.id,
            restrictPublicBuckets: true,
            blockPublicPolicy: true,
            blockPublicAcls: true,
            ignorePublicAcls: true,
        }, resourceOpts);

        new aws.s3.BucketServerSideEncryptionConfiguration(`${name}-recordings-sse`, {
            bucket: recordingsBucket.id,
            rules: [{
                applyServerSideEncryptionByDefault: {
                    sseAlgorithm: "aws:kms",
                },
            }],
        }, resourceOpts);

        new aws.s3.BucketLifecycleConfiguration(`${name}-recordings-lifecycle`, {
            bucket: recordingsBucket.id,
            rules: [{
                id: "expire-recordings",
                status: "Enabled",
                expiration: { days: recordingsRetentionDays },
                abortIncompleteMultipartUpload: { daysAfterInitiation: 7 },
            }],
        }, resourceOpts);

        new aws.s3.BucketPolicy(`${name}-recordings-policy`, {
            bucket: recordingsBucket.id,
            policy: recordingsBucket.arn.apply(arn => JSON.stringify({
                Version: "2012-10-17",
                Statement: [{
                    Sid: "AllowAgentCoreRecordings",
                    Effect: "Allow",
                    Principal: { Service: "bedrock-agentcore.amazonaws.com" },
                    Action: "s3:PutObject",
                    Resource: `${arn}/*`,
                }],
            })),
        }, resourceOpts);

        // IAM role for AgentCore Browser
        const agentCoreTrustPolicy = JSON.stringify({
            Version: "2012-10-17",
            Statement: [{
                Effect: "Allow",
                Action: "sts:AssumeRole",
                Principal: { Service: "bedrock-agentcore.amazonaws.com" },
            }],
        });

        const browserRole = new aws.iam.Role(`${name}-browser-role`, {
            name: "baz-browser-execution",
            assumeRolePolicy: agentCoreTrustPolicy,
            tags: commonTags,
        }, resourceOpts);

        new aws.iam.RolePolicy(`${name}-browser-policy`, {
            name: "baz-browser-execution",
            role: browserRole.id,
            policy: recordingsBucket.arn.apply(arn => JSON.stringify({
                Version: "2012-10-17",
                Statement: [
                    {
                        Sid: "S3WriteRecordings",
                        Effect: "Allow",
                        Action: ["s3:PutObject", "s3:PutObjectAcl"],
                        Resource: `${arn}/*`,
                    },
                    {
                        Sid: "KMSEncrypt",
                        Effect: "Allow",
                        Action: ["kms:Decrypt", "kms:GenerateDataKey"],
                        Resource: "*",
                    },
                ],
            })),
        }, resourceOpts);

        // IAM role for AgentCore Runtime
        const runtimeRole = new aws.iam.Role(`${name}-runtime-role`, {
            name: "baz-spec-login-runtime",
            assumeRolePolicy: agentCoreTrustPolicy,
            tags: commonTags,
        }, resourceOpts);

        // IAM role for cross-account access (Baz assumes this)
        const crossAccountRole = new aws.iam.Role(`${name}-cross-account-role`, {
            name: "baz-spec-login-cross-account",
            assumeRolePolicy: pulumi.all([args.bazAwsAccountId, externalIdResource.result]).apply(
                ([accountId, extId]) => JSON.stringify({
                    Version: "2012-10-17",
                    Statement: [{
                        Effect: "Allow",
                        Action: "sts:AssumeRole",
                        Principal: { AWS: `arn:aws:iam::${accountId}:root` },
                        Condition: {
                            StringEquals: { "sts:ExternalId": extId },
                        },
                    }],
                })
            ),
            tags: commonTags,
        }, resourceOpts);

        // Security group for browser ENIs (VPC mode only)
        const browserSg = args.enableVpc
            ? new aws.ec2.SecurityGroup(`${name}-browser-sg`, {
                name: "baz-browser-tool-sg",
                description: "Security group for AgentCore Browser ENIs",
                vpcId: args.vpcId,
                egress: [{
                    description: "HTTPS to preview env",
                    fromPort: 443,
                    toPort: 443,
                    protocol: "tcp",
                    cidrBlocks: [args.previewEnvCidr as pulumi.Input<string>, "0.0.0.0/0"],
                }],
                tags: commonTags,
            }, resourceOpts)
            : undefined;

        // AgentCore Browser
        const browser = new aws.bedrock.AgentcoreBrowser(`${name}-browser`, {
            name: "baz_spec_review",
            executionRoleArn: browserRole.arn,
            networkConfiguration: {
                networkMode: args.enableVpc ? "VPC" : "PUBLIC",
                ...(args.enableVpc && browserSg ? {
                    vpcConfig: {
                        subnets: args.subnetIds!,
                        securityGroups: [browserSg.id],
                    },
                } : {}),
            },
            recording: {
                enabled: true,
                s3Location: {
                    bucket: recordingsBucket.bucket,
                    prefix: "browser-recordings/",
                },
            },
            tags: commonTags,
        }, resourceOpts);

        // Runtime IAM policy — depends on browser ARN
        new aws.iam.RolePolicy(`${name}-runtime-policy`, {
            name: "baz-spec-login-runtime",
            role: runtimeRole.id,
            policy: browser.browserArn.apply(browserArn => JSON.stringify({
                Version: "2012-10-17",
                Statement: [
                    {
                        Sid: "SSMGetParameter",
                        Effect: "Allow",
                        Action: "ssm:GetParameter",
                        Resource: "arn:aws:ssm:*:*:parameter/*",
                    },
                    {
                        Sid: "BrowserSession",
                        Effect: "Allow",
                        Action: [
                            "bedrock-agentcore:StartBrowserSession",
                            "bedrock-agentcore:GetBrowserSession",
                            "bedrock-agentcore:ConnectBrowserAutomationStream",
                            "bedrock-agentcore:StopBrowserSession",
                        ],
                        Resource: browserArn,
                    },
                ],
            })),
        }, resourceOpts);

        // SSM parameter lookups — validates params exist at deploy time (mirrors TF data sources)
        const ssmUsername = aws.ssm.getParameterOutput({ name: args.ssmUsernamePath }, { parent: this });
        const ssmPassword = aws.ssm.getParameterOutput({ name: args.ssmPasswordPath }, { parent: this });

        // AgentCore Runtime
        const runtime = new aws.bedrock.AgentcoreAgentRuntime(`${name}-runtime`, {
            agentRuntimeName: "baz_spec_login",
            roleArn: runtimeRole.arn,
            agentRuntimeArtifact: {
                containerConfiguration: {
                    containerUri: handlerImageUri,
                },
            },
            networkConfiguration: {
                networkMode: "PUBLIC",
            },
            environmentVariables: {
                SSM_USERNAME_PATH: ssmUsername.name,
                SSM_PASSWORD_PATH: ssmPassword.name,
                BROWSER_ID: browser.browserId,
            },
            tags: commonTags,
        }, resourceOpts);

        // Cross-account IAM policy — depends on runtime ARN + browser ARN
        new aws.iam.RolePolicy(`${name}-cross-account-policy`, {
            name: "baz-spec-login-cross-account",
            role: crossAccountRole.id,
            policy: pulumi.all([runtime.agentRuntimeArn, browser.browserArn]).apply(
                ([runtimeArn, browserArn]) => JSON.stringify({
                    Version: "2012-10-17",
                    Statement: [
                        {
                            Sid: "InvokeRuntime",
                            Effect: "Allow",
                            Action: "bedrock-agentcore:InvokeAgentRuntime",
                            Resource: [runtimeArn, `${runtimeArn}/*`],
                        },
                        {
                            Sid: "BrowserAccess",
                            Effect: "Allow",
                            Action: [
                                "bedrock-agentcore:ConnectBrowserAutomationStream",
                                "bedrock-agentcore:StopBrowserSession",
                            ],
                            Resource: browserArn,
                        },
                    ],
                })
            ),
        }, resourceOpts);

        // PrivateLink resources (conditional on enablePrivateLink + enableVpc)
        if (args.enablePrivateLink && args.enableVpc && args.subnetIds) {
            const subnetIds = args.subnetIds;
            const subnetCidrs = pulumi.output(subnetIds).apply(ids =>
                Promise.all(ids.map(id => aws.ec2.getSubnet({ id })))
            ).apply(subnets => subnets.map(s => s.cidrBlock));

            const privateLinkSg = new aws.ec2.SecurityGroup(`${name}-privatelink-sg`, {
                name: "baz-agentcore-endpoint-sg",
                description: "Security group for AgentCore PrivateLink endpoint ENIs",
                vpcId: args.vpcId,
                ingress: [{
                    description: "HTTPS from private subnets",
                    fromPort: 443,
                    toPort: 443,
                    protocol: "tcp",
                    cidrBlocks: subnetCidrs,
                }],
                tags: commonTags,
            }, resourceOpts);

            new aws.ec2.VpcEndpoint(`${name}-agentcore-endpoint`, {
                vpcId: args.vpcId as pulumi.Input<string>,
                serviceName: `com.amazonaws.${region}.bedrock-agentcore`,
                vpcEndpointType: "Interface",
                subnetIds: subnetIds,
                securityGroupIds: [privateLinkSg.id],
                privateDnsEnabled: true,
                tags: commonTags,
            }, resourceOpts);
        }

        this.crossAccountRoleArn = crossAccountRole.arn;
        this.runtimeArn = runtime.agentRuntimeArn;
        this.browserId = browser.browserId;
        this.externalId = pulumi.secret(externalIdResource.result);
        this.browserSecurityGroupId = browserSg ? browserSg.id : pulumi.output(undefined);

        this.registerOutputs({
            crossAccountRoleArn: this.crossAccountRoleArn,
            runtimeArn: this.runtimeArn,
            browserId: this.browserId,
            externalId: this.externalId,
            browserSecurityGroupId: this.browserSecurityGroupId,
        });
    }
}
