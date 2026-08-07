locals {
  name_prefix = "${var.project_name}-${var.environment}"

  required_tags = {
    owner       = var.owner_tag
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  }
}

resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.required_tags
}

# ---------------------------------------------------------------------------
# App Service (the "payments API" from the run-of-show script)
# ---------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.required_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.name_prefix}-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = local.required_tags

  https_only = true

  site_config {
    minimum_tls_version = "1.2"

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    "SQL_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=placeholder)" # wire to Key Vault in a real env
    "ENVIRONMENT"            = var.environment
  }
}

# ---------------------------------------------------------------------------
# SQL Server + Database
# ---------------------------------------------------------------------------

resource "random_password" "sql_admin" {
  length      = 20
  special     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.name_prefix}-${random_string.unique.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"

  # THE DEMO FLASHPOINT:
  # When this is `true`, the SQL server accepts connections from any public
  # IP. Terraform will happily apply this - Terraform enforces syntax and
  # provider schema, not security posture. That gap is exactly what the AI
  # reviewer step in the GitHub Action is there to close.
  public_network_access_enabled = var.sql_public_network_access_enabled

  tags = local.required_tags
}

resource "azurerm_mssql_database" "main" {
  name         = "sqldb-${local.name_prefix}"
  server_id    = azurerm_mssql_server.main.id
  sku_name     = var.sql_sku_name
  zone_redundant = false
  tags         = local.required_tags
}

# Locks the SQL server down to Azure services only when public access is off.
# When someone flips sql_public_network_access_enabled to true, this rule
# becomes meaningless - which is itself a good talking point live.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  count            = var.sql_public_network_access_enabled ? 0 : 1
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
