output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "app_service_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_public_network_access_enabled" {
  value       = var.sql_public_network_access_enabled
  description = "Should be false. If this shows true, the AI review step should have flagged it."
}

output "sql_admin_password" {
  value     = random_password.sql_admin.result
  sensitive = true
}
