# Quick Fix: Use OIDC Properly

## 🚨 **Your Current Issue**

You're using OIDC authentication but then retrieving AWS credentials from Secrets Manager - this defeats the entire purpose of OIDC!

## ✅ **Quick Fix Steps**

### 1. **Update Your AWS Secrets Manager Secret**

**Replace this** (what you probably have now):
```json
{
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "AWS_SECRET_ACCESS_KEY": "...",
  "AWS_BUCKET_NAME": "my-bucket",
  "AWS_CLOUDFRONT_DISTRIBUTION_ID": "E123..."
}
```

**With this** (application secrets only):
```bash
aws secretsmanager update-secret \
    --secret-id "gitops-deploy-secret" \
    --secret-string file://example-app-secrets.json
```

### 2. **Configure GitHub Secrets**

Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:
```
AWS_ROLE_ARN: arn:aws:iam::YOUR_ACCOUNT:role/GitHubActions-REPO-Role
AWS_BUCKET_NAME: your-s3-bucket-name
AWS_CLOUDFRONT_DISTRIBUTION_ID: your-distribution-id
SECRET_NAME: gitops-deploy-secret
```

### 3. **Run OIDC Setup (If Not Done)**

```bash
# Check what's already set up
./debug-oidc-error.sh

# Run setup if needed
./manual-oidc-setup.sh
```

### 4. **Test Your Workflow**

Your workflow should now:
- ✅ Use OIDC for AWS authentication (no access keys)
- ✅ Retrieve only application secrets from Secrets Manager
- ✅ Use GitHub secrets for infrastructure identifiers

## 🎯 **Result**

- **No AWS credentials stored anywhere**
- **Maximum security** with temporary tokens
- **Automatic credential rotation**
- **AWS handles all authentication**

## 📋 **Verification**

After the fix, your workflow:
1. Gets temporary AWS credentials via OIDC
2. Uses those credentials to access Secrets Manager
3. Retrieves application secrets (API keys, database URLs, etc.)
4. Deploys to S3 and invalidates CloudFront
5. Temporary credentials expire automatically

## ❓ **Still Confused?**

Read `UNDERSTAND-OIDC.md` for a detailed explanation of how OIDC works and why it's more secure. 