import { PrivateSpecReviewer } from "@baz/pulumi-private-spec-reviewer";

// To test with VPC + PrivateLink, replace IDs and use this instead:
// const reviewer = new PrivateSpecReviewer("private-spec-reviewer", {
//     bazAwsAccountId: "647348643223",
//     ssmUsernamePath: "/bazai/preview/username",
//     ssmPasswordPath: "/bazai/preview/password",
//     region: "eu-central-1",
//     enableVpc: true,
//     vpcId: "vpc-xxxxxxxxx",
//     subnetIds: ["subnet-xxx", "subnet-yyy", "subnet-zzz"],
//     previewEnvCidr: "10.0.0.0/16",
//     enablePrivateLink: true,
//     tags: { Env: "test" },
// });

const reviewer = new PrivateSpecReviewer("private-spec-reviewer", {
    bazAwsAccountId: "647348643223",
    ssmUsernamePath: "/bazai/preview/username",
    ssmPasswordPath: "/bazai/preview/password",
    region: "eu-central-1",
    enableVpc: false,
    enablePrivateLink: false,
    tags: { Env: "test" },
});

export const crossAccountRoleArn = reviewer.crossAccountRoleArn;
export const externalId = reviewer.externalId;
export const runtimeArn = reviewer.runtimeArn;
export const browserId = reviewer.browserId;
