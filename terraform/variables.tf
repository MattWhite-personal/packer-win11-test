variable "repository" {
  type        = string
  description = "Github repository name"
  sensitive   = false
}

variable "packer_sp_object_id" {
  type        = string
  description = "Object ID of the existing Packer service principal in Azure AD"
  sensitive   = false
}

variable "github_actions_sp_object_id" {
  type        = string
  description = "Object ID of the existing GitHub Actions service principal in Azure AD"
  sensitive   = false
}

variable "github_org" {
  type        = string
  description = "GitHub organization name"
  sensitive   = false
}

variable "runner-ip" {
  type        = string
  description = "IP address of the GitHub Actions runner"
  sensitive   = true
}

variable "image_publisher" {
  type        = string
  description = "Publisher of the base image for the Shared Image Gallery"
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  type        = string
  description = "Offer of the base image for the Shared Image Gallery"
  default     = "windows-11"
}

variable "image_sku" {
  type        = string
  description = "SKU of the base image for the Shared Image Gallery"
  default     = "win11-25h2-pro"
}