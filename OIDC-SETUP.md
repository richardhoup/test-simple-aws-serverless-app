# AWS OIDC Setup for GitHub Actions

This guide explains how to set up OIDC (OpenID Connect) authentication so your GitHub Actions can access AWS services without storing long-term AWS access keys.

## 🔐 Why Use OIDC?

- **More Secure**: No long-term credentials stored in GitHub
- **AWS Best Practice**: Recommended by AWS for CI/CD pipelines
- **Audit Trail**: All access is logged through AWS CloudTrail
- **Automatic Rotation**: Temporary credentials are automatically generated

## 📋 Prerequisites

1. AWS CLI installed and configured with admin permissions
2. GitHub repository with Actions enabled
3. Existing AWS resources (S3 bucket, CloudFront distribution)

## 🚀 Setup Options

### Option 1: Automated Setup (Recommended)

```bash
./setup-aws-oidc.sh
```

This script will:
- Create OIDC identity provider in AWS
- Create IAM role with proper trust policy
- Create permissions policy
- Output the GitHub secrets you need to configure

### Option 2: Manual Setup (If automated fails)

If you get the "MalformedPolicyDocument" error, use the manual setup:

```bash
./manual-oidc-setup.sh
```

This script breaks down the process step-by-step and includes proper wait times for AWS resource propagation.

### Option 3: Check Existing Setup

To see what's already configured in AWS:

```bash
./check-aws-oidc.sh
```

## 📝 After Running Setup Script

### Step 1: Create Your Application Secrets in AWS Secrets Manager

```bash
# Create a secret with your application secrets
aws secretsmanager create-secret \
    --name "my-app-secrets" \
    --secret-string file://example-secret.json \
    --description "Application secrets for GitHub Actions deployment"
```

See `example-secret.json` for the format.

### Step 2: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets (output from the setup script):
- `AWS_ROLE_ARN`: The ARN of the IAM role created
- `AWS_BUCKET_NAME`: Your S3 bucket name
- `AWS_CLOUDFRONT_DISTRIBUTION_ID`: Your CloudFront distribution ID
- `SECRET_NAME`: Name of your secret in AWS Secrets Manager (default: "my-app-secrets")

### Step 3: Verify Your Workflow

Your workflow file (`.github/workflows/main.yml`) is already configured to use OIDC. Key points:

```yaml
# Required permissions for OIDC
permissions:
  id-token: write
  contents: read

# Use OIDC instead of access keys
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1

# Retrieve secrets from AWS Secrets Manager
- name: Get secrets from AWS Secrets Manager
  run: |
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${{ secrets.SECRET_NAME }}" --query SecretString --output text)
    echo "API_KEY=$(echo $SECRET_JSON | jq -r '.api_key')" >> $GITHUB_ENV
```

## 🔧 What Gets Created

### AWS Resources:
- **OIDC Identity Provider**: `token.actions.githubusercontent.com`
- **IAM Role**: `GitHubActions-{REPO_NAME}-Role`
- **IAM Policy**: `GitHubActions-{REPO_NAME}-Policy`

### Permissions Granted:
- `secretsmanager:GetSecretValue` - Read application secrets
- `s3:PutObject`, `s3:ListBucket` - Deploy to S3
- `cloudfront:CreateInvalidation` - Clear CloudFront cache

## 🛡️ Security Features

### Trust Policy
Only allows access from:
- Your specific GitHub repository
- Your specific branch (`deploy/gitops`)
- Valid GitHub OIDC tokens

### Resource Restrictions
- Secrets Manager: Only your specific secret
- S3: Only your specific bucket
- CloudFront: Only your specific distribution

## 🔍 Troubleshooting

### Common Issues:

1. **"MalformedPolicyDocument: Federated principals must be valid domain names"**
   - The OIDC provider doesn't exist yet or wasn't created properly
   - Solution: Run `./manual-oidc-setup.sh` for step-by-step setup
   - Or wait a few minutes and try `./setup-aws-oidc.sh` again

2. **"No credentials found"**
   - Check that `permissions.id-token: write` is set in workflow
   - Verify GitHub secrets are configured correctly

3. **"Access denied to secret"**
   - Check the secret name matches in GitHub secrets and AWS
   - Verify the IAM policy includes the correct secret ARN

4. **"Cannot assume role"**
   - Check the trust policy allows your repository and branch
   - Verify the role ARN in GitHub secrets is correct

### Debug Steps:

```bash
# Check if OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust policy
aws iam get-role --role-name GitHubActions-{REPO_NAME}-Role

# Test secret access (locally)
aws secretsmanager get-secret-value --secret-id my-app-secrets
```

## 📚 Additional Resources

- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS Secrets Manager CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/)

## 🧹 Cleanup

To remove the setup:

```bash
# Delete the IAM role and policy
aws iam detach-role-policy --role-name GitHubActions-{REPO_NAME}-Role --policy-arn arn:aws:iam::{ACCOUNT_ID}:policy/GitHubActions-{REPO_NAME}-Policy
aws iam delete-role --role-name GitHubActions-{REPO_NAME}-Role
aws iam delete-policy --policy-arn arn:aws:iam::{ACCOUNT_ID}:policy/GitHubActions-{REPO_NAME}-Policy

# Delete OIDC provider (if not used by other repositories)
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::{ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com
``` 