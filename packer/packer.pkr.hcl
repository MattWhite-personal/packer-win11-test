packer {
  required_plugins {
    azure = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "location" {
  type    = "string"
  default = "uksouth"
}

source "azure-arm" "win11" {
  tenant_id       = "$${env ARM_TENANT_ID}"
  subscription_id = "$${env ARM_SUBSCRIPTION_ID}"
  client_id       = "$${env ARM_CLIENT_ID}"
  # For GitHub Actions OIDC authentication do NOT provide a client secret here.
  # When running in Actions set ARM_USE_OIDC=true and ensure the Azure AD
  # application has a federated credential for the repository; Packer will
  # use the OIDC token exchange instead of client credentials.

  location                          = var.location
  vm_size                           = "Standard_D4s_v3"
  image_publisher                   = "MicrosoftWindowsDesktop"
  image_offer                       = "windows-11"
  image_sku                         = "win11-25h2-pro"
  managed_image_resource_group_name = "rg-whitefam-image-gallery"
  managed_image_name                = "win11-custom-{{timestamp}}"
  communicator                      = "winrm"
  winrm_use_ssl                     = true
  winrm_insecure                    = true
  winrm_timeout                     = "1h"
}

build {
  name    = "win11-image"
  sources = ["source.azure-arm.win11"]

  provisioner "file" {
    source      = "scripts"
    destination = "C:\\\\build-scripts"
  }

  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "C:\\\\build-scripts\\\\install-updates.ps1",
      "C:\\\\build-scripts\\\\install-office.ps1"
    ]
  }
}
