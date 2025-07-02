#!/bin/bash

echo "🔍 Debugging OIDC Setup Error"
echo "=============================="
echo ""

# Check AWS CLI
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account ID: $ACCOUNT_ID"
echo ""

# Check OIDC providers
echo "🔗 Checking OIDC Providers:"
echo "----------------------------"
aws iam list-open-id-connect-providers

PROVIDER_COUNT=$(aws iam list-open-id-connect-providers --query "length(OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')])" --output text)

if [ "$PROVIDER_COUNT" = "0" ]; then
    echo ""
    echo "❌ ISSUE FOUND: No GitHub OIDC provider exists!"
    echo ""
    echo "🔧 SOLUTION: The OIDC provider needs to be created first."
    echo "Run one of these commands:"
    echo ""
    echo "Option 1 (Manual step-by-step):"
    echo "  ./manual-oidc-setup.sh"
    echo ""
    echo "Option 2 (Create provider only):"
    echo "  aws iam create-open-id-connect-provider \\"
    echo "    --url https://token.actions.githubusercontent.com \\"
    echo "    --client-id-list sts.amazonaws.com \\"
    echo "    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd"
    echo ""
    echo "Then wait 2-3 minutes and try './setup-aws-oidc.sh' again."
else
    PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)
    echo ""
    echo "✅ GitHub OIDC provider exists: $PROVIDER_ARN"
    echo ""
    echo "🔧 The provider exists, so the error might be:"
    echo "1. Recent creation - wait 2-3 minutes for AWS propagation"
    echo "2. Permission issue - ensure you have iam:CreateRole permissions"
    echo "3. Try the manual setup: ./manual-oidc-setup.sh"
fi

echo ""
echo "📋 Your AWS IAM Permissions:"
echo "----------------------------"
echo "Testing required permissions..."

# Test permissions
echo -n "iam:CreateRole: "
if aws iam get-account-summary >/dev/null 2>&1; then
    echo "✅ (likely available)"
else
    echo "❌ (check your permissions)"
fi

echo -n "iam:CreatePolicy: "
if aws iam list-policies --max-items 1 >/dev/null 2>&1; then
    echo "✅ (likely available)"
else
    echo "❌ (check your permissions)"
fi

echo -n "iam:CreateOpenIDConnectProvider: "
if aws iam list-open-id-connect-providers >/dev/null 2>&1; then
    echo "✅ (can list providers)"
else
    echo "❌ (check your permissions)"
fi

