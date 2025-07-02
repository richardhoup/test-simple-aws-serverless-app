#!/bin/bash

# AWS OIDC Setup for GitHub Actions
# This script sets up OIDC authentication so GitHub Actions can access AWS without storing access keys

echo "🚀 Setting up AWS OIDC for GitHub Actions..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account ID: $ACCOUNT_ID"

# Prompt for GitHub repository details
echo "📝 Please provide your GitHub repository details:"
read -p "GitHub Username/Organization: " GITHUB_USER
read -p "Repository Name: " REPO_NAME
read -p "Branch (default: deploy/gitops): " BRANCH
BRANCH=${BRANCH:-deploy/gitops}

# Prompt for AWS resource details
echo "📝 Please provide your AWS resource details:"
read -p "S3 Bucket Name: " BUCKET_NAME
read -p "CloudFront Distribution ID: " DISTRIBUTION_ID
read -p "Secrets Manager Secret Name (default: your-app-secrets): " SECRET_NAME
SECRET_NAME=${SECRET_NAME:-your-app-secrets}

echo "🔧 Creating OIDC provider..."

# Check if OIDC provider already exists
PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)

if [ -z "$PROVIDER_ARN" ]; then
    echo "Creating OIDC provider for GitHub Actions..."
    PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
        --query Arn --output text)
    
    if [ $? -ne 0 ] || [ -z "$PROVIDER_ARN" ]; then
        echo "❌ Failed to create OIDC provider. Please check your AWS permissions."
        exit 1
    fi
    
    echo "✅ OIDC provider created: $PROVIDER_ARN"
    
    # Wait a moment for AWS to propagate the provider
    echo "⏳ Waiting for OIDC provider to propagate..."
    sleep 5
else
    echo "✅ OIDC provider already exists: $PROVIDER_ARN"
fi

# Verify PROVIDER_ARN is valid
if [ -z "$PROVIDER_ARN" ] || [[ ! "$PROVIDER_ARN" =~ ^arn:aws:iam::[0-9]+:oidc-provider/ ]]; then
    echo "❌ Invalid OIDC provider ARN: $PROVIDER_ARN"
    echo "Please check if the OIDC provider was created correctly."
    exit 1
fi

# Create trust policy with actual values
echo "📄 Creating trust policy..."
cat > trust-policy-actual.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$PROVIDER_ARN"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_USER/$REPO_NAME:ref:refs/heads/$BRANCH"
        }
      }
    }
  ]
}
EOF

# Create permissions policy with actual values
echo "📄 Creating permissions policy..."
cat > permissions-policy-actual.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:$ACCOUNT_ID:secret:$SECRET_NAME*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME/*",
        "arn:aws:s3:::$BUCKET_NAME"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation"
      ],
      "Resource": [
        "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$DISTRIBUTION_ID"
      ]
    }
  ]
}
EOF

# Create IAM role
ROLE_NAME="GitHubActions-$REPO_NAME-Role"
echo "🔐 Creating IAM role: $ROLE_NAME..."

# Check if role already exists
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "⚠️  Role already exists. Updating trust policy..."
    aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document file://trust-policy-actual.json
    if [ $? -ne 0 ]; then
        echo "❌ Failed to update role trust policy"
        exit 1
    fi
else
    echo "Creating IAM role..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://trust-policy-actual.json \
        --description "Role for GitHub Actions OIDC access"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create IAM role. Common issues:"
        echo "1. OIDC provider may not be ready yet - try running the script again in a few minutes"
        echo "2. Check your AWS permissions (need iam:CreateRole)"
        echo "3. Check the trust policy format in trust-policy-actual.json"
        exit 1
    fi
    echo "✅ Role created successfully!"
fi

# Create and attach permissions policy
POLICY_NAME="GitHubActions-$REPO_NAME-Policy"
echo "📋 Creating permissions policy: $POLICY_NAME..."

# Check if policy exists
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    echo "⚠️  Policy already exists. Creating new version..."
    aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document file://permissions-policy-actual.json \
        --set-as-default
else
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file://permissions-policy-actual.json \
        --description "Permissions for GitHub Actions deployment" \
        --query Policy.Arn --output text)
    echo "✅ Policy created: $POLICY_ARN"
fi

# Attach policy to role
echo "🔗 Attaching policy to role..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📝 GitHub Secrets to configure:"
echo "=================================="
echo "AWS_ROLE_ARN: $ROLE_ARN"
echo "AWS_BUCKET_NAME: $BUCKET_NAME"
echo "AWS_CLOUDFRONT_DISTRIBUTION_ID: $DISTRIBUTION_ID"
echo ""
echo "🔧 Next steps:"
echo "1. Go to your GitHub repository settings"
echo "2. Navigate to Secrets and variables > Actions"
echo "3. Add the above secrets"
echo "4. Make sure your workflow file is configured to use OIDC"
echo ""
echo "🗂️  Files created:"
echo "- trust-policy-actual.json"
echo "- permissions-policy-actual.json"

echo ""
echo "📁 Policy files saved for reference:"
echo "- trust-policy-actual.json"
echo "- permissions-policy-actual.json"
echo ""
echo "✅ You can now use GitHub Actions without storing AWS access keys!" 