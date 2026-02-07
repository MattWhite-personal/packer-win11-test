resource "azurerm_role_assignment" "packer_storage_blob_contributor" {
  scope                = azurerm_storage_account.image-storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
