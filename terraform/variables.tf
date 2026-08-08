variable "project_name" {
  description = "Short name used to prefix all resources"
  type        = string
  default     = "aidemo"
}

variable "environment" {
  description = "Environment tag: dev, staging, or prod"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Existing resource group where Terraform should deploy resources. Defaults to rg-<project_name>-<environment>."
  type        = string
  default     = null
}

variable "owner_tag" {
  description = "Who owns this environment, for the required-tags policy"
  type        = string
  default     = "platform-team"
}

variable "app_service_sku" {
  description = "App Service Plan SKU. Keep this at a demo-safe tier."
  type        = string
  default     = "B1" # Basic tier - cheap, fine for a demo, NOT for prod

  validation {
    # This is the kind of guardrail the AI reviewer step also checks for,
    # so the room can see the same rule enforced in two places: in code
    # (fails fast, no plan even generated) and in the AI review comment
    # (catches it even if this validation block didn't exist).
    condition     = contains(["B1", "B2", "S1"], var.app_service_sku)
    error_message = "app_service_sku must be a demo-approved cost tier (B1, B2, S1). Talk to platform-team before requesting anything larger."
  }
}

variable "sql_admin_login" {
  description = "SQL Server admin username"
  type        = string
  default     = "sqladmin"
}

variable "sql_public_network_access_enabled" {
  description = <<-EOT
    Controls whether the SQL server allows public network access.

    DEMO NOTE: this defaults to false (secure). During the live session,
    a second branch flips this to true on purpose so the AI reviewer step
    in the PR catches it. Do not merge that branch's version of this default.
  EOT
  type        = bool
  default     = false
}

variable "sql_sku_name" {
  description = "Azure SQL Database SKU (tier)"
  type        = string
  default     = "Basic" # cheap, demo-appropriate
}
