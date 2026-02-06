# packer-win11-test

This workspace contains Terraform and Packer scaffolding to build a customized Windows 11 Pro image with Microsoft 365 Apps for Enterprise and latest updates. The built image is automatically exported to a WIM file and stored in Azure Blob Storage.

The build is automated via GitHub Actions using Azure federated credentials (OIDC) for secure authentication without managing secrets.

## Quick setup (local build)

### Prerequisites

- Azure subscription with Contributor or higher role
- Existing Azure AD service principal for Packer (with Client ID, Secret, Tenant ID)
- Packer v1.9+ installed locally
- Terraform v1.0+ installed locally

### Steps

1. Create a `terraform.tfvars` file with your service principal details:

```hcl
packer_sp_object_id = "<object-id-of-packer-service-principal>"
```

2. Initialize Terraform and apply to create Azure resources:

```powershell
cd terraform
terraform init
terraform apply -auto-approve
```

3. Capture Terraform outputs for use with Packer:

```powershell
$storageAccount = terraform output -raw image_storage_account_name
$container = terraform output -raw image_container_name
$sasUrl = terraform output -raw image_storage_account_sas_url
```

4. Set environment variables for Packer authentication (using existing Packer SP credentials):

```powershell
$env:ARM_CLIENT_ID = "<your-packer-sp-client-id>"
$env:ARM_CLIENT_SECRET = "<your-packer-sp-client-secret>"
$env:ARM_TENANT_ID = "<your-azure-tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<your-azure-subscription-id>"
```

5. Build the image from the repository root:

```powershell
cd ..
packer build `
  -var "storage_account_name=$storageAccount" `
  -var "storage_container_name=$container" `
  -var "storage_sas_url=$sasUrl" `
  packer\packer.pkr.hcl
```

## GitHub Actions setup (automated builds)

This repository includes a GitHub Actions workflow that automatically builds the image using an existing GitHub Actions service principal.

### Prerequisites

- Existing GitHub Actions service principal in Azure AD
- Service principal object ID
- Service principal configured with federated credentials for GitHub OIDC
- Service principal has Contributor role at subscription level

### Setup steps

1. Update `terraform.tfvars` with your service principal details:

```hcl
packer_sp_object_id = "<object-id-of-packer-service-principal>"
github_actions_sp_object_id = "<object-id-of-github-actions-service-principal>"
````markdown
# packer-win11-test

This workspace contains Terraform and Packer scaffolding to build a customized Windows 11 Pro managed image with Microsoft 365 Apps for Enterprise and latest updates.

Important: WIM export and remote upload are deferred for future development. The current pipeline builds a managed image in Azure and the CI workflow publishes that managed image to the Shared Image Gallery (SIG). WIM capture/management is present in the codebase as commented examples and is not executed by default.

The build is automated via GitHub Actions using Azure federated credentials (OIDC) for secure authentication without storing client secrets.

## Quick setup (local build)

### Prerequisites

- Azure subscription with Contributor or higher role (or appropriate least-privilege roles)
- Existing Azure AD service principals (object IDs must be supplied to Terraform)
- Packer v1.9+ installed locally
- Terraform v1.0+ installed locally

### Steps (local)

1. Create a `terraform.tfvars` file with your service principal object IDs:

```hcl
packer_sp_object_id = "<object-id-of-packer-service-principal>"
github_actions_sp_object_id = "<object-id-of-github-actions-service-principal>"
github_org = "<your-github-organization>"
```

2. Initialize Terraform and apply to create Azure resources (role assignments, SIG, etc.):

```powershell
cd terraform
terraform init
terraform apply -auto-approve
```

3. (Optional) For local Packer builds use an Azure service principal credential pair and export ARM env vars:

```powershell
$env:ARM_CLIENT_ID = "<your-packer-sp-client-id>"
$env:ARM_CLIENT_SECRET = "<your-packer-sp-client-secret>"
$env:ARM_TENANT_ID = "<your-azure-tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<your-azure-subscription-id>"
```

4. Build the image locally (managed image will be created in Azure):

```powershell
cd ..
packer init packer/packer.pkr.hcl
packer build packer/packer.pkr.hcl
```

## GitHub Actions setup (automated builds)

This repository includes `packer-build.yml` which builds the image in CI and publishes the managed image to the Shared Image Gallery.

### Prerequisites

- Existing GitHub Actions service principal in Azure AD with a federated credential for this repository (OIDC)
- Service principal object IDs supplied to Terraform via `terraform.tfvars`

### GitHub secrets required for the workflow

- `AZURE_CLIENT_ID` (client id used by `azure/login`) is required for the `azure/login` action
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `PACKER_SP_OBJECT_ID` (object id used by Terraform role assignments)
- `GITHUB_ACTIONS_SP_OBJECT_ID` (object id used by Terraform role assignments)

> Note: The Packer process in the workflow uses GitHub OIDC (`ARM_USE_OIDC=true`) — do NOT store long-lived client secrets in the repository.

### Triggering the build

The `packer-build.yml` workflow runs on pushes to `main` that touch `packer/` or by manual workflow dispatch.

## What this does today

- **Terraform**: creates resource group, Shared Image Gallery (SIG) and role assignments that grant the supplied service principals the rights they need. Terraform does not create Entra applications/service principals — supply existing object IDs via `terraform.tfvars`.
- **Packer**: builds a managed image (Azure Managed Image) from Windows 11 Pro, runs updates and Office installation provisioners, and produces a managed image artifact in the specified resource group.
- **CI**: the workflow extracts the managed image id from the Packer manifest and calls `az sig image-version create` to publish a SIG image version.

## WIM capture and upload

- WIM capture and upload scripts (`packer/scripts/export-wim.ps1` and `packer/scripts/capture-and-upload-wim.ps1`) remain in the repository as commented examples inside `packer/packer.pkr.hcl` for future work.
- Live (in-guest) WIM capture is fragile and often requires an offline/WinPE capture process; for production WIM workflows plan to use an offline capture and `az storage`/AzCopy for uploads.

## Notes and next steps

- Consider hardening the workflow manifest parsing and adding a `publish_to_gallery` toggle for CI.
- When implementing WIM capture, prefer offline capture (WinPE) and `az storage blob upload` or AzCopy for reliable large-file transfers.
- Confirm Azure AD federated credential configuration for GitHub OIDC before running CI.

### Troubleshooting

- **Azure Login fails**: verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` repository secrets and the federated credential on the corresponding Azure AD app.
- **Packer timeouts**: adjust `winrm_timeout` in `packer/packer.pkr.hcl` or use a larger VM size.

# packer-win11-test
Create and maintain a clean Windows 11 image

````
