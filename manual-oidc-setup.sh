#!/bin/bash

# Manual OIDC Setup for GitHub Actions - Step by Step
# Use this if the automated script fails

echo "🔧 Manual OIDC Setup for GitHub Actions"
echo "========================================"
echo ""

# Check AWS CLI
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account ID: $ACCOUNT_ID"
echo ""

# Step 1: Check/Create OIDC Provider
echo "Step 1: OIDC Provider"
echo "---------------------"

# Check existing providers
echo "Checking existing OIDC providers..."
aws iam list-open-id-connect-providers

PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)

if [ -z "$PROVIDER_ARN" ]; then
    echo ""
    echo "🔧 Creating OIDC provider for GitHub Actions..."
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
    
    if [ $? -eq 0 ]; then
        echo "✅ OIDC provider created successfully!"
        PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    else
        echo "❌ Failed to create OIDC provider"
        exit 1
    fi
else
    echo "✅ OIDC provider already exists: $PROVIDER_ARN"
fi

echo ""
echo "Provider ARN: $PROVIDER_ARN"
echo ""

# Step 2: Get Repository Information
echo "Step 2: Repository Information"
echo "------------------------------"

read -p "GitHub Username/Organization: " GITHUB_USER
read -p "Repository Name: " REPO_NAME
read -p "Branch (default: deploy/gitops): " BRANCH
BRANCH=${BRANCH:-deploy/gitops}

echo ""
echo "Repository: $GITHUB_USER/$REPO_NAME"
echo "Branch: $BRANCH"
echo ""

# Step 3: Create Trust Policy
echo "Step 3: Creating Trust Policy"
echo "-----------------------------"

cat > trust-policy-manual.json << EOF
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

echo "✅ Trust policy created: trust-policy-manual.json"
echo "Trust policy content:"
cat trust-policy-manual.json | jq .
echo ""

# Step 4: Create IAM Role
echo "Step 4: Creating IAM Role"
echo "-------------------------"

ROLE_NAME="GitHubActions-$REPO_NAME-Role"
echo "Role name: $ROLE_NAME"

# Wait before creating role
echo "⏳ Waiting 10 seconds for OIDC provider to propagate..."
sleep 10

echo "Creating IAM role..."
aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy-manual.json \
    --description "Role for GitHub Actions OIDC access"

if [ $? -eq 0 ]; then
    echo "✅ Role created successfully!"
else
    echo "❌ Failed to create role. Checking if it already exists..."
    if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
        echo "⚠️  Role already exists. Updating trust policy..."
        aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document file://trust-policy-manual.json
    else
        echo "❌ Role creation failed. Please check the error above."
        exit 1
    fi
fi

echo ""

# Step 5: Get AWS Resources
echo "Step 5: AWS Resources"
echo "--------------------"

read -p "S3 Bucket Name: " BUCKET_NAME
read -p "CloudFront Distribution ID: " DISTRIBUTION_ID
read -p "Secrets Manager Secret Name (default: my-app-secrets): " SECRET_NAME
SECRET_NAME=${SECRET_NAME:-my-app-secrets}

echo ""

# Step 6: Create Permissions Policy
echo "Step 6: Creating Permissions Policy"
echo "-----------------------------------"

cat > permissions-policy-manual.json << EOF
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

echo "✅ Permissions policy created: permissions-policy-manual.json"
echo ""

# Step 7: Create and Attach Policy
echo "Step 7: Creating and Attaching Policy"
echo "-------------------------------------"

POLICY_NAME="GitHubActions-$REPO_NAME-Policy"
echo "Policy name: $POLICY_NAME"

POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://permissions-policy-manual.json \
    --description "Permissions for GitHub Actions deployment" \
    --query Policy.Arn --output text)

if [ $? -eq 0 ]; then
    echo "✅ Policy created: $POLICY_ARN"
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
    
    echo "✅ Policy attached to role"
else
    echo "⚠️  Policy might already exist. Checking..."
    POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
    if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
        echo "✅ Policy already exists: $POLICY_ARN"
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN"
        echo "✅ Policy attached to role"
    else
        echo "❌ Failed to create policy"
        exit 1
    fi
fi

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

echo ""
echo "🎉 Manual setup completed!"
echo "=========================="
echo ""
echo "📝 GitHub Secrets to configure:"
echo "AWS_ROLE_ARN: $ROLE_ARN"
echo "AWS_BUCKET_NAME: $BUCKET_NAME"
echo "AWS_CLOUDFRONT_DISTRIBUTION_ID: $DISTRIBUTION_ID"
echo "SECRET_NAME: $SECRET_NAME"
echo ""
echo "📁 Files created:"
echo "- trust-policy-manual.json"
echo "- permissions-policy-manual.json" 