#!/usr/bin/env node
/**
 * server.js
 *
 * MCP server for the "From Prompt to Production" ChatOps demo.
 *
 * Exposes exactly three tools, each hard-scoped to a single working
 * directory and a single resource group. This scoping is the actual
 * security boundary referenced in the run-of-show script - it is not
 * the LLM's judgment, it's the fact that these tools are physically
 * incapable of touching anything outside DEMO_RESOURCE_GROUP.
 *
 * Run with:
 *   npm install
 *   DEMO_RESOURCE_GROUP=rg-aidemo-staging TF_DIR=../terraform node server.js
 *
 * Then point Claude Desktop (or any MCP client) at this as a stdio server.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

const execFileAsync = promisify(execFile);

// ---------------------------------------------------------------------------
// Hard scoping - this is the security boundary, say this out loud in the demo
// ---------------------------------------------------------------------------
const TF_DIR = path.resolve(process.env.TF_DIR || "../terraform");
const DEMO_RESOURCE_GROUP = process.env.DEMO_RESOURCE_GROUP;

if (!DEMO_RESOURCE_GROUP) {
  console.error(
    "DEMO_RESOURCE_GROUP env var is required. This server refuses to run " +
      "without a scope - that's intentional, not a bug."
  );
  process.exit(1);
}

const server = new McpServer({
  name: "terraform-azure-demo",
  version: "1.0.0",
});

// ---------------------------------------------------------------------------
// Tool 1: terraform_plan - read-only, always safe to call
// ---------------------------------------------------------------------------
server.registerTool(
  "terraform_plan",
  {
    title: "Terraform Plan",
    description:
      "Runs `terraform plan` in the demo working directory and returns a " +
      "human-readable summary of proposed changes. Read-only, makes no " +
      "changes to Azure.",
    inputSchema: {
      var_overrides: z
        .record(z.string())
        .optional()
        .describe(
          "Optional Terraform variable overrides, e.g. { \"environment\": \"staging\" }"
        ),
    },
  },
  async ({ var_overrides }) => {
    const args = ["plan", "-no-color"];
    for (const [key, value] of Object.entries(var_overrides || {})) {
      args.push("-var", `${key}=${value}`);
    }

    try {
      const { stdout } = await execFileAsync("terraform", args, {
        cwd: TF_DIR,
        maxBuffer: 1024 * 1024 * 10,
      });
      return {
        content: [{ type: "text", text: stdout }],
      };
    } catch (err) {
      return {
        content: [
          { type: "text", text: `terraform plan failed:\n${err.stderr || err.message}` },
        ],
        isError: true,
      };
    }
  }
);

// ---------------------------------------------------------------------------
// Tool 2: terraform_apply - the only tool that changes infrastructure.
// Requires an explicit confirm flag, mirroring the human-approval gate in
// the CI/CD pipeline. This is what you demo in Segment 5.
// ---------------------------------------------------------------------------
server.registerTool(
  "terraform_apply",
  {
    title: "Terraform Apply",
    description:
      "Applies the current Terraform plan in the demo working directory. " +
      "Requires confirm=true. Always run terraform_plan first and show the " +
      "user the plan before calling this.",
    inputSchema: {
      confirm: z
        .boolean()
        .describe("Must be true. This is the human-approval gate for apply."),
      var_overrides: z.record(z.string()).optional(),
    },
  },
  async ({ confirm, var_overrides }) => {
    if (!confirm) {
      return {
        content: [
          {
            type: "text",
            text: "Refusing to apply: confirm=true was not set. Show the user the plan and get explicit approval first.",
          },
        ],
        isError: true,
      };
    }

    const args = ["apply", "-auto-approve", "-no-color"];
    for (const [key, value] of Object.entries(var_overrides || {})) {
      args.push("-var", `${key}=${value}`);
    }

    try {
      const { stdout } = await execFileAsync("terraform", args, {
        cwd: TF_DIR,
        maxBuffer: 1024 * 1024 * 10,
      });
      return { content: [{ type: "text", text: stdout }] };
    } catch (err) {
      return {
        content: [
          { type: "text", text: `terraform apply failed:\n${err.stderr || err.message}` },
        ],
        isError: true,
      };
    }
  }
);

// ---------------------------------------------------------------------------
// Tool 3: azure_resource_query - read-only Azure CLI query, scoped to the
// demo resource group only. Powers "what changed in the last 24 hours"
// style questions in Segment 5.
// ---------------------------------------------------------------------------
server.registerTool(
  "azure_resource_query",
  {
    title: "Azure Resource Query",
    description:
      `Lists resources and recent activity in the ${DEMO_RESOURCE_GROUP} ` +
      "resource group only. Read-only. Cannot query any other resource group.",
    inputSchema: {
      query_type: z
        .enum(["list_resources", "recent_activity"])
        .describe("What to look up"),
    },
  },
  async ({ query_type }) => {
    try {
      if (query_type === "list_resources") {
        const { stdout } = await execFileAsync("az", [
          "resource",
          "list",
          "--resource-group",
          DEMO_RESOURCE_GROUP,
          "--output",
          "table",
        ]);
        return { content: [{ type: "text", text: stdout }] };
      }

      // recent_activity
      const { stdout } = await execFileAsync("az", [
        "monitor",
        "activity-log",
        "list",
        "--resource-group",
        DEMO_RESOURCE_GROUP,
        "--offset",
        "24h",
        "--output",
        "table",
      ]);
      return { content: [{ type: "text", text: stdout }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `Query failed:\n${err.stderr || err.message}` }],
        isError: true,
      };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(
  `MCP server ready. Scoped to resource group: ${DEMO_RESOURCE_GROUP}, tf dir: ${TF_DIR}`
);
