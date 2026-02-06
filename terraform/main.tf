terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.58.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraformrg"
    storage_account_name = "terraformstoragefe832e63"
    container_name       = "terraform"
    key                  = "tf-packer.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

resource "azurerm_resource_group" "image-gallery" {
  name     = "rg-whitefam-image-gallery"
  location = "uksouth"
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = "sig-whitefam-gallery"
  resource_group_name = azurerm_resource_group.image-gallery.name
  location            = azurerm_resource_group.image-gallery.location
  description         = "Shared Image Gallery for Win11 golden image"
  tags                = local.tags
}

resource "azurerm_shared_image" "win11-pro" {
  name                = "win11-pro"
  resource_group_name = azurerm_resource_group.image-gallery.name
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  location            = azurerm_resource_group.image-gallery.location
  os_type             = "Windows"
  description         = "Win11 golden image created by Packer"
  tags                = local.tags
  hyper_v_generation  = "V2"

  identifier {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
  }
}

resource "azurerm_storage_account" "image-storage" {
  #checkov:skip=CKV2_AZURE_1:Ignore what i dont care about
  #checkov:skip=CKV2_AZURE_21: Ignore
  #checkov:skip=CKV2_AZURE_33: Private endpoints not suitable for storage account
  #checkov:skip=CKV_AZURE_33:Ignore
  #checkov:skip=CKV2_AZURE_40: Shared Key currently enabled until Entra Auth is tested
  #checkov:skip=CKV2_AZURE_41: Storage account is not internet facing and only used for image upload, so Shared Key is acceptable
  #checkov:skip=CKV_AZURE_206: ignore
  #checkov:skip=CKV_AZURE_190: Own naming convention is in use
  #checkov:skip=CKV_AZURE_59:Own naming convention is in use
  #checkov:skip=CKV2_AZURE_47:Own naming convention is in use
  #checkov:skip=CKV2_AZURE_38:IGnore
  name                     = "stwhitefamimages"
  resource_group_name      = azurerm_resource_group.image-gallery.name
  location                 = azurerm_resource_group.image-gallery.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "image-container" {
  #checkov:skip=CKV2_AZURE_21: Ignore
  #checkov:skip=CKV2_AZURE_38:IGnore
  name                  = "images"
  storage_account_name  = azurerm_storage_account.image-storage.name
  container_access_type = "private"
}

resource "azurerm_storage_account_sas" "image_sas" {
  storage_account_name = azurerm_storage_account.image-storage.name
  resource_types {
    service   = true
    container = true
    object    = true
  }
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  start  = timestamp()
  expiry = timeadd(timestamp(), "24h")
  permissions {
    read                    = true
    write                   = true
    delete                  = false
    list                    = true
    create                  = true
    update                  = false
    process                 = false
    delete_previous_version = false
    tag                     = false
    filter                  = false
  }
}