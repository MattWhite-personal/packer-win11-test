packer {
  required_plugins {
    azure = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
    windows-update = {
      version = "0.17.2"
      source  = "github.com/rgl/windows-update"
    }
  }
}

source "azure-arm" "win11" {
  use_azure_cli_auth = true

  location                          = "UK South"
  os_type                           = "Windows"
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

  # Windows updates
  provisioner "windows-update" {
    filters         = ["exclude:$_.Title -like '*Preview*'", "include:$true"]
    search_criteria = "IsInstalled=0"
    update_limit    = 25
  }

  provisioner "powershell" {
    inline = [
      "New-Item -Path 'C:\\build-scripts' -ItemType Directory -Force"
    ]
  }

  provisioner "file" {
    # use explicit relative path from repo root where packer is executed
    source      = "./packer/scripts/"
    destination = "C:\\build-scripts\\"
  }

  provisioner "powershell" {
    script = "C:\\build-scripts\\install-office.ps1"
  }
}
