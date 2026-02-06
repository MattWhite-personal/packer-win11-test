# Role assignments for Packer and GitHub Actions service principals

# Role assignment for Packer SP: Contributor on the resource group
resource "azurerm_role_assignment" "packer_sp_contributor" {
  scope                = azurerm_resource_group.image-gallery.id
  role_definition_name = "Contributor"
  principal_id         = var.packer_sp_object_id
}

# Role assignment for GitHub Actions SP: Contributor on the resource group
resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = azurerm_resource_group.image-gallery.id
  role_definition_name = "Contributor"
  principal_id         = var.github_actions_sp_object_id
}

# Role assignment for GitHub Actions SP: Contributor at subscription level for shared resources
resource "azurerm_role_assignment" "github_actions_subscription" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = var.github_actions_sp_object_id
}
