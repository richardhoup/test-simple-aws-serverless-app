/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      profile: "default",
      name: "test-simple-aws-serverless-app-main",
      removal: input?.stage === "production" ? "retain" : "remove",
      protect: ["production"].includes(input?.stage),
      home: "aws",
    };
  },
  async run() {
    new sst.aws.Nextjs("MyWeb");
  },
});
