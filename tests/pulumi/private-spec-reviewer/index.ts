import * as aws from "@pulumi/aws";
import * as awsx from "@pulumi/awsx";
import { PrivateSpecReviewer } from "@baz/pulumi-private-spec-reviewer";

// VPC mirroring tests/private-spec-reviewer/main.tf:
// 3 AZs, private + public subnets, single NAT gateway
const vpc = new awsx.ec2.Vpc("private-spec-reviewer-test-vpc", {
    cidrBlock: "10.0.0.0/16",
    numberOfAvailabilityZones: 3,
    subnetSpecs: [
        { type: awsx.ec2.SubnetType.Private, cidrMask: 24 },
        { type: awsx.ec2.SubnetType.Public, cidrMask: 24 },
    ],
    natGateways: { strategy: awsx.ec2.NatGatewayStrategy.Single },
    enableDnsHostnames: true,
    tags: { Environment: "test", Module: "private-spec-reviewer" },
});

// SSM parameters holding test credentials
const usernameParam = new aws.ssm.Parameter("test-username", {
    name: "/bazai/preview/username",
    type: aws.ssm.ParameterType.SecureString,
    value: "test-user",
});

const passwordParam = new aws.ssm.Parameter("test-password", {
    name: "/bazai/preview/password",
    type: aws.ssm.ParameterType.SecureString,
    value: "test-password",
});

const reviewer = new PrivateSpecReviewer("private-spec-reviewer", {
    bazAwsAccountId: "647348643223",
    ssmUsernamePath: usernameParam.name,
    ssmPasswordPath: passwordParam.name,
    region: "eu-central-1",
    enableVpc: true,
    vpcId: vpc.vpcId,
    subnetIds: vpc.privateSubnetIds,
    previewEnvCidr: "10.0.0.0/16",
    enablePrivateLink: true,
    tags: { Env: "test" },
}, { dependsOn: [usernameParam, passwordParam] });

export const crossAccountRoleArn = reviewer.crossAccountRoleArn;
export const externalId = reviewer.externalId;
export const runtimeArn = reviewer.runtimeArn;
export const browserId = reviewer.browserId;
