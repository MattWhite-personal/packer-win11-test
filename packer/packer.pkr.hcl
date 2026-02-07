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

locals {
  today               = timestamp()                   # current UTC timestamp
  three_months        = timeadd(local.today, "2160h") # 3 months ~ 90 days = 2160 hours
  first_of_next_month = formatdate("YYYY-MM-01'T'00:00:00Z", timeadd(local.three_months, "720h"))
  expiry_date         = formatdate("YYYY-MM-DD", timeadd(local.first_of_next_month, "-24h"))
  build_timestamp     = formatdate("YYYYMMDDHHmmss", local.today)
}

source "azure-arm" "win11-25h2" {
  use_azure_cli_auth = true

  location        = "UK South"
  os_type         = "Windows"
  vm_size         = "Standard_D4s_v3"
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-11"
  image_sku       = "win11-25h2-pro"
  communicator    = "winrm"
  winrm_use_ssl   = true
  winrm_insecure  = true
  winrm_timeout   = "1h"

  # ---------- Managed Image (optional but fine to keep)
  #managed_image_resource_group_name = "rg-whitefam-image-gallery"
  #managed_image_name                = "win11-custom-{{timestamp}}"

  # ---------- Azure Compute Gallery output
  shared_image_gallery_destination {
    resource_group = "rg-whitefam-image-gallery"
    gallery_name   = "sig_whitefam_gallery"
    image_name     = "win11-pro"
    image_version  = "1.0.{{timestamp}}"

    replication_regions = [
      "UK South"
    ]
  }
}

build {
  name    = "win11-image"
  sources = ["source.azure-arm.win11-25h2"]

  # Create local directory for build scripts and artefacts 
  provisioner "powershell" {
    inline = [
      "New-Item -Path 'C:\\build-scripts' -ItemType Directory -Force"
    ]
  }

  # Copy scripts to target directory
  provisioner "file" {
    # use explicit relative path from repo root where packer is executed
    source      = "./packer/scripts/"
    destination = "C:\\build-scripts\\"
  }

  # Get Current OS status
  provisioner "powershell" {
    script           = "./packer/scripts/get-locale-versions.ps1"
    environment_vars = ["ExecutionStage=pre"]
  }
  #provisioner "file" {
  #  source      = "C:\\build-scripts\\locale-versions-pre.json"
  #  destination = "./packer/scripts/locale-versions-pre.json"
  #}

  # --- Set locale to en-GB and reboot ---
  provisioner "powershell" {
    script = "./packer/scripts/set-language_en-gb.ps1"
  }
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
    restart_timeout = "60m"
  }

  provisioner "powershell" {
    script = "./packer/scripts/install-update-module.ps1"
  }

  # Install MS Office based on ODT and defined configuration
  provisioner "powershell" {
    script = "./packer/scripts/install-office.ps1"
  }

  #Windows updates
  provisioner "windows-update" {
    filters         = ["exclude:$_.Title -like '*Preview*'", "include:$true"]
    search_criteria = "IsInstalled=0"
    update_limit    = 25
  }

  # Get Current OS status post deployment and update results
  provisioner "powershell" {
    script           = "./packer/scripts/get-locale-versions.ps1"
    environment_vars = ["ExecutionStage=pre"]
  }
  #provisioner "file" {
  #  source      = "C:\\build-scripts\\locale-versions-post.json"
  #  destination = "./packer/scripts/locale-versions-post.json"
  #}

  post-processor "manifest" {
    output        = "packer-manifest.json"
    strip_path    = true
  }
}
