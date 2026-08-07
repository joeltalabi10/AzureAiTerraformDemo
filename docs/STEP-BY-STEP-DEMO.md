# Step-by-Step Demo: Start to Finish

This is the literal sequence of commands and actions for the live session.
Run through it once fully, alone, at least 24 hours before you present.
Then again, fully, the morning of. Do not skip the rehearsal.

---

## Part 0 — Prerequisites (do this before demo day)

Tools installed locally:
```bash
az --version          # Azure CLI
terraform --version   # >= 1.7.0
node --version         # >= 20.x
python3 --version      # >= 3.10
gh --version            # GitHub CLI (optional but convenient)
```

Accounts / access needed:
- Azure subscription with permission to create resource groups and role assignments
- GitHub repo (this project pushed to it)
- DeepSeek API key

---

## Part 1 — One-Time Setup (day before)

```bash
cd azure-ai-terraform-demo

# 1. Log into Azure
az login

# 2. Set the env vars setup.sh needs
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export GITHUB_ORG="<your-github-org-or-username>"
export GITHUB_REPO="azure-ai-terraform-demo"

# 3. Run setup - creates the scoped RG, service principal, and OIDC trust
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This prints four values. Add them as GitHub repo secrets under
**Settings > Secrets and variables > Actions**:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `DEEPSEEK_API_KEY`

Then, in **Settings > Environments**, create an environment named
`production` and add yourself (or a co-presenter) as a required reviewer.
This is the human-approval gate the whole session is built around — confirm
it's actually configured before you go on stage.

Copy the example vars file:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Do a full dry run now, alone:
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
# confirm resources exist in the Azure portal
terraform destroy -auto-approve
cd ..
```

If this doesn't work cleanly today, it won't work live tomorrow. Fix it now.

---

## Part 2 — MCP Server Setup (for the ChatOps segments)

```bash
cd mcp-server
npm install

# Test it standalone first
DEMO_RESOURCE_GROUP=rg-aidemo-staging TF_DIR=../terraform node server.js
# You should see: "MCP server ready. Scoped to resource group: rg-aidemo-staging..."
# Ctrl+C to stop.
```

Connect it to Claude Desktop by adding to your MCP config
(`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "terraform-azure-demo": {
      "command": "node",
      "args": ["/absolute/path/to/azure-ai-terraform-demo/mcp-server/server.js"],
      "env": {
        "DEMO_RESOURCE_GROUP": "rg-aidemo-staging",
        "TF_DIR": "/absolute/path/to/azure-ai-terraform-demo/terraform"
      }
    }
  }
}
```
Restart Claude Desktop. Confirm the three tools (`terraform_plan`,
`terraform_apply`, `azure_resource_query`) show up in the tool list before
you're on stage — don't discover a config typo live.

---

## Part 3 — Live Session Sequence

### Step 1 — Cold open (Segment 1)
In Claude Desktop, with the MCP server connected, type:
> "Show me the current terraform plan for the demo environment"

Claude calls `terraform_plan`, shows the proposed resources in plain English.
Then:
> "Apply it"

Claude confirms it's about to call `terraform_apply`, asks you to confirm —
say yes out loud so the room hears the gate happen. It applies. Switch to
the Azure portal tab, refresh, show the resource group populating.

### Step 2 — Architecture walkthrough (Segment 3)
No commands here — this is the diagram + talking through `main.tf`,
`variables.tf`, and the workflow file on screen. Open:
- `terraform/main.tf` — narrate the `public_network_access_enabled` toggle specifically, it's about to matter
- `.github/workflows/terraform-ai-pipeline.yml` — narrate the `environment: production` gate on the apply job
- `scripts/setup.sh` output from Part 1 — show the actual role assignment scope in the Azure portal (IAM blade on the resource group)

### Step 3 — Hands-on build, clean path (Segment 4, steps 1–2)
Hand the keyboard to a volunteer.

```bash
git checkout -b demo/payments-staging
# volunteer edits terraform/main.tf or variables.tf with AI assistance
# (e.g. via Claude in an IDE) to add or adjust a resource
git add .
git commit -m "Add staging config for payments environment"
git push -u origin demo/payments-staging
```

Open the PR on GitHub. Watch the `Terraform AI Pipeline` workflow run.
Point at the PR comment when it lands — that's `scripts/ai_review.py`
calling DeepSeek with the plan JSON.

### Step 4 — The flaw (Segment 4, step 3 — the highest-value moment)
Switch to the pre-staged broken branch instead of writing it live (safer):

```bash
git checkout -b demo/insecure-sql
cp terraform/terraform.tfvars.broken-demo terraform/terraform.tfvars
git add terraform/terraform.tfvars
git commit -m "demo: staging DB for payments"
git push -u origin demo/insecure-sql
```

Open this PR live. Narrate while the workflow runs:
> "This branch sets the SQL server to allow public network access. Terraform
> itself won't stop this — it's syntactically valid. Watch what the AI
> review step does."

The PR comment should come back with **Verdict: NEEDS ATTENTION**, calling
out `azurerm_mssql_server.main` and the policy rule it violates (this is
defined in `scripts/ai_review.py`'s `POLICY_RULES`).

### Step 5 — Fix and merge (Segment 4, steps 4–5)
```bash
git checkout demo/payments-staging  # back to the clean branch
```
Merge that PR through the GitHub UI. Watch the `apply` job queue up and
sit waiting — this is the `production` environment gate. Click **Approve**
in the GitHub Actions UI live, narrate that this is a human, not an AI,
making this call. Watch it apply.

Verify:
```bash
cd terraform
terraform output
# confirm sql_public_network_access_enabled = false in the output
```

### Step 6 — ChatOps finale (Segment 5)
Back in Claude Desktop:
> "What changed in the demo resource group in the last 24 hours?"

Claude calls `azure_resource_query` with `recent_activity`.

> "Spin up a staging copy of the payments environment we just built"

Claude calls `terraform_plan`, shows the diff, asks for confirmation.
> "Approved"

Claude calls `terraform_apply`. Confirm in the portal.

---

## Part 4 — Teardown (immediately after, don't wait)

```bash
export TF_DIR=terraform
export RG_NAME=rg-aidemo-staging
chmod +x scripts/teardown.sh
./scripts/teardown.sh
```

Confirm in the Azure portal that `rg-aidemo-staging` is gone. Also delete
the app registration created in Part 1 if you won't reuse it:
```bash
az ad app delete --id "<APP_ID from setup.sh output>"
```

---

## Fallback Plan

If live Azure, GitHub Actions, or the MCP connection fails mid-session:
1. Say so plainly — "looks like we lost connectivity, let's not wait on it"
2. Switch to the screen recording of the full happy path (you made one in
   pre-session prep — see the checklist in the run-of-show script)
3. Keep narrating over the recording as if it were live; the content is
   identical, the audience mostly won't mind

Do not troubleshoot live for more than ~30 seconds. It kills momentum.
