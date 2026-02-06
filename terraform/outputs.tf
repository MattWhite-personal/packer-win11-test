output "resource_group_name" {
  value = azurerm_resource_group.image-gallery.name
}

output "image_storage_account_name" {
  value = azurerm_storage_account.image-storage.name
}

output "image_container_name" {
  value = azurerm_storage_container.image-container.name
}

output "image_storage_account_sas_url" {
  value     = "?${azurerm_storage_account_sas.image_sas.sas}"
  sensitive = true
}

output "image_storage_primary_blob_endpoint" {
  value     = azurerm_storage_account.image-storage.primary_blob_endpoint
  sensitive = false
}

data "azurerm_client_config" "current" {}
