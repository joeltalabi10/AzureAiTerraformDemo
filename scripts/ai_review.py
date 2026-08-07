#!/usr/bin/env python3
"""
ai_review.py

Reads a `terraform show -json` plan file, sends the resource changes to
DeepSeek along with the team's policy rules, and writes a markdown review
to review_comment.md for the GitHub Action to post on the PR.

Usage:
    python3 ai_review.py <plan.json> <output.md>

Requires:
    DEEPSEEK_API_KEY environment variable
    pip install openai
"""

import json
import sys
import os

POLICY_RULES = """
Platform team policy rules to check the plan against:

1. No resource may set public network access to enabled for a database
   (public_network_access_enabled = true is a violation for any *sql* or
   *cosmosdb* resource).
2. Every resource must carry tags: owner, environment, project, managed_by.
3. App Service Plan SKU must be one of: B1, B2, S1. Anything larger requires
   manual sign-off and should be flagged, not silently allowed.
4. TLS: minimum_tls_version must be 1.2 or higher wherever the attribute exists.
5. https_only must be true on any App Service / Web App resource.
6. Flag (do not necessarily block) anything that looks like a secret or
   connection string being set as a plain string literal instead of a
   reference to Key Vault.
"""

SYSTEM_PROMPT = f"""You are an infrastructure security and cost reviewer for a
platform engineering team. You will be given the JSON output of a Terraform
plan (resource_changes array). Review it against the following policy rules
and produce a concise markdown review suitable for posting as a GitHub PR
comment.

{POLICY_RULES}

Format your response as markdown with this structure:

## AI Infrastructure Review

**Verdict:** PASS or NEEDS ATTENTION

### Findings
- One bullet per issue found, referencing the specific resource address and
  the specific policy rule it violates. If there are no issues, say so
  plainly.

### Notes
- Anything worth a human's attention that isn't a hard policy violation
  (cost, unusual configuration, etc).

Be specific and cite resource addresses (e.g. azurerm_mssql_server.main).
Do not invent issues that aren't in the plan. Keep it under 200 words.
"""


def load_resource_changes(plan_path: str) -> list:
    with open(plan_path, "r") as f:
        plan = json.load(f)
    changes = plan.get("resource_changes", [])
    # Trim to just what matters for review - address, type, and the proposed
    # 'after' values - to keep token usage sane on large plans.
    trimmed = []
    for c in changes:
        change = c.get("change", {})
        trimmed.append(
            {
                "address": c.get("address"),
                "type": c.get("type"),
                "actions": change.get("actions"),
                "after": change.get("after"),
            }
        )
    return trimmed


def main():
    if len(sys.argv) != 3:
        print("Usage: ai_review.py <plan.json> <output.md>")
        sys.exit(1)

    plan_path, output_path = sys.argv[1], sys.argv[2]

    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        print("DEEPSEEK_API_KEY is not set", file=sys.stderr)
        sys.exit(1)

    resource_changes = load_resource_changes(plan_path)

    if not resource_changes:
        with open(output_path, "w") as f:
            f.write("## AI Infrastructure Review\n\n**Verdict:** PASS\n\nNo resource changes in this plan.\n")
        return

    try:
        from openai import OpenAI
    except ImportError:
        print("The openai package is not installed. Run: pip install openai", file=sys.stderr)
        sys.exit(1)

    client = OpenAI(
        api_key=api_key,
        base_url=os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com"),
    )
    model = os.environ.get("DEEPSEEK_MODEL", "deepseek-v4-flash")

    response = client.chat.completions.create(
        model=model,
        max_tokens=800,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"Here is the plan's resource_changes:\n\n{json.dumps(resource_changes, indent=2)}",
            }
        ],
    )

    review_text = response.choices[0].message.content or ""

    with open(output_path, "w") as f:
        f.write(review_text)

    # Exit non-zero if the review flagged a problem, so the workflow can
    # optionally use this as a soft gate (see the workflow file for how
    # this is wired - it's advisory by default, not blocking).
    if "NEEDS ATTENTION" in review_text:
        print("AI review found issues.")
        sys.exit(2)

    print("AI review passed.")


if __name__ == "__main__":
    main()
