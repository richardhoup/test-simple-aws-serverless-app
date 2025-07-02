#!/bin/bash

echo "🔍 Checking OIDC setup in AWS..."

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

echo "📋 AWS Account ID: $ACCOUNT_ID"

# Check OIDC provider
echo ""
echo "🔗 OIDC Providers:"
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')]" --output table

# List roles with GitHub in the name
echo ""
echo "��️  GitHub Actions Roles:"
aws iam list-roles --query "Roles[?contains(RoleName, 'GitHubActions')].[RoleName,Arn]" --output table

# If we find a role, show its trust policy
ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'GitHubActions')].RoleName" --output text | head -1)

if [ ! -z "$ROLE_NAME" ]; then
    echo ""
    echo "📋 Trust Policy for role: $ROLE_NAME"
    aws iam get-role --role-name "$ROLE_NAME" --query Role.AssumeRolePolicyDocument --output json | jq .
    
    echo ""
    echo "🔑 Attached Policies:"
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" --output table
    
    # Get the policy details
    POLICY_ARN=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[0].PolicyArn" --output text)
    if [ ! -z "$POLICY_ARN" ] && [ "$POLICY_ARN" != "None" ]; then
        echo ""
        echo "📄 Policy Document:"
        POLICY_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query Policy.DefaultVersionId --output text)
        aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$POLICY_VERSION" --query PolicyVersion.Document --output json | jq .
    fi
fi
