#!/usr/bin/env bash
# setup.sh
# One-time setup: creates a scoped resource group and an Azure AD app
# registration with OIDC federation for GitHub Actions - no long-lived
# secrets stored anywhere. Run this once, the day before your session.

set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID first}"
: "${GITHUB_ORG:?Set GITHUB_ORG (e.g. your-org)}"
: "${GITHUB_REPO:?Set GITHUB_REPO (e.g. azure-ai-terraform-demo)}"

RG_NAME="${RG_NAME:-rg-aidemo-staging}"
LOCATION="${LOCATION:-eastus}"
APP_NAME="${APP_NAME:-sp-aidemo-github-actions}"

echo "==> Logging into Azure"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

echo "==> Creating scoped resource group: $RG_NAME"
az group create --name "$RG_NAME" --location "$LOCATION" \
  --tags owner=platform-team environment=staging managed_by=terraform

echo "==> Creating app registration: $APP_NAME"
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID" >/dev/null

echo "==> Scoping the service principal to ONLY $RG_NAME (least privilege)"
RG_ID=$(az group show --name "$RG_NAME" --query id -o tsv)
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "$RG_ID"

echo "==> Configuring OIDC federated credential for GitHub Actions"
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-actions-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-actions-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

TENANT_ID=$(az account show --query tenantId -o tsv)

cat <<EOF

==> Done. Add these as GitHub repo secrets (Settings > Secrets > Actions):

  AZURE_CLIENT_ID       = $APP_ID
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $AZURE_SUBSCRIPTION_ID
  DEEPSEEK_API_KEY      = <your DeepSeek API key>

Resource group scope: $RG_NAME (the service principal can ONLY touch this RG)

This is the IAM scope to show on screen in Segment 3 of the run-of-show.
EOF
