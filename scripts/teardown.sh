#!/usr/bin/env bash
# teardown.sh
# Run this after the session. Do not skip this - a demo subscription
# left running is the most expensive part of any live demo.

set -euo pipefail

TF_DIR="${TF_DIR:-../terraform}"
RG_NAME="${RG_NAME:-rg-aidemo-staging}"

echo "==> Destroying everything Terraform knows about"
cd "$TF_DIR"
terraform destroy -auto-approve

echo "==> Sanity check: deleting the resource group directly in case anything"
echo "    was created out-of-band during the demo (e.g. the drift-detection beat)"
az group delete --name "$RG_NAME" --yes --no-wait

echo "==> Done. Verify in the portal that $RG_NAME is gone within a few minutes."
