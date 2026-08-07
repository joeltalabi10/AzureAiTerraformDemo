<<<<<<< HEAD
# AI-Augmented Terraform on Azure — Live Demo Kit

Companion repo to the "From Prompt to Production" workshop. This is a
working (not simulated) implementation of the four AI touchpoints in the
IaC lifecycle: **Author → Review → Deploy → Operate**.

## Start here

👉 **[`docs/STEP-BY-STEP-DEMO.md`](docs/STEP-BY-STEP-DEMO.md)** — the literal,
start-to-finish sequence of commands for the live session. Everything below
is reference; that file is the script.

## What's in this repo

```
terraform/                          Azure App Service + SQL module
  main.tf                           Resources (has the deliberate demo toggle)
  variables.tf
  outputs.tf
  providers.tf
  terraform.tfvars.example          Clean path
  terraform.tfvars.broken-demo      Deliberate flaw, for the AI-review demo moment

.github/workflows/
  terraform-ai-pipeline.yml         plan -> AI review -> PR comment -> human-gated apply

scripts/
  ai_review.py                      Calls DeepSeek to review the terraform plan JSON
  setup.sh                          One-time: scoped RG + OIDC service principal
  teardown.sh                       Cleanup after the session

mcp-server/
  server.js                         MCP server: terraform_plan, terraform_apply,
                                     azure_resource_query — powers the ChatOps demo
```

## The four touchpoints, and where to find them

| Touchpoint | Where |
|---|---|
| **Author** | AI-assisted editing of `terraform/*.tf` in your IDE (Segment 4) |
| **Review** | `scripts/ai_review.py`, called from the GitHub Actions workflow |
| **Deploy** | `.github/workflows/terraform-ai-pipeline.yml` — plan, review, human-gated apply |
| **Operate** | `mcp-server/server.js` — the ChatOps agent |

## Security boundaries (say these out loud in the demo)

- The Azure service principal is scoped to **one resource group only**
  (see `scripts/setup.sh`) — not subscription-level access.
- `terraform_apply` in the MCP server refuses to run without an explicit
  `confirm: true` — mirrors the human-approval gate in CI/CD.
- The GitHub Actions `apply` job runs behind a `production` environment
  with a required reviewer — nothing applies without a human clicking Approve.
- The AI review step is **advisory by default** (see `continue-on-error` in
  the workflow) — you decide live whether to make it a hard gate, which is
  a good audience discussion point.

## Cost

Everything defaults to the cheapest viable SKU (App Service B1, SQL Basic).
Still — run `scripts/teardown.sh` immediately after the session.
=======
# AzureAiTerraformDemo
>>>>>>> 03df2aafbd65ccf8b3a34f2f771adbf5a3dfe1de
