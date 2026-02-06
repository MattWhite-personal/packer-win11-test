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
github_org = "<your-github-organization>"
```

2. In your GitHub repository settings, add the following secrets (Settings → Secrets and variables → Actions):
   - `AZURE_CLIENT_ID`: Your Packer service principal's client ID
   - `AZURE_TENANT_ID`: Your Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
   - `PACKER_SP_OBJECT_ID`: Object ID of your Packer service principal
   - `GITHUB_ACTIONS_SP_OBJECT_ID`: Object ID of your GitHub Actions service principal

3. Apply Terraform to create role assignments:

```bash
cd terraform
terraform apply -auto-approve
```

4. Optionally, create a GitHub environment named `production` in Settings → Environments for additional protection.

### Triggering the build

The Packer build can be triggered in two ways:

**1. Automatically on push (requires secrets set)**
Push changes to `packer/` directory on the main branch. The workflow will use `STORAGE_ACCOUNT_NAME`, `STORAGE_CONTAINER_NAME`, and `STORAGE_SAS_URL` secrets.

**2. Manual workflow dispatch**
Trigger via GitHub Actions tab → "Build Windows 11 Packer Image" → Run workflow and provide:
- Storage Account Name
- Storage Container Name  
- Storage SAS URL

### Workflow separation

This repository uses separate workflows for infrastructure and image builds:

- **tf-drift.yml**: Detects and reports infrastructure drift (scheduled)
- **tf-unit-tests.yml**: Validates Terraform code (on PRs)
- **tf-plan-apply.yml**: Plans and applies Terraform changes to Azure (on main branch pushes to terraform/)
- **packer-build.yml**: Builds the Windows 11 image with Packer (on main branch pushes to packer/, or manual trigger)

The **tf-plan-apply** workflow must run successfully before **packer-build** can execute, as it provisions the storage account and SAS token needed for image uploads.

## What this does

- **Terraform** creates a resource group, Azure AD application/service principal, storage account, blob container, and SAS token. Outputs provide credentials and storage details for Packer.
- **Packer template** (`packer/packer.pkr.hcl`) builds a managed image from Windows 11 Pro, then:
  1. Runs Windows Updates (`install-updates.ps1`)
  2. Installs Microsoft 365 Apps for Enterprise (`install-office.ps1`)
  3. Optimizes the OS and runs Sysprep to generalize (`export-wim.ps1`):
     - Clears temp files, Windows Update cache, event logs, and DNS cache
     - Disables telemetry services
     - Runs Sysprep with `/generalize`, `/oobe`, and unattend.xml
  4. Waits for system to reboot
  5. Captures the sysprepped OS to a WIM file with maximum compression (`capture-and-upload-wim.ps1`)
  6. Uploads the optimized WIM to the blob container using the SAS URL

The resulting WIM file is suitable for deployment outside of Azure using standard Windows deployment tools (WDS, MDT, DISM, etc.).

## Notes and next steps

- The Office Deployment Tool URL in `packer/scripts/install-office.ps1` is an example; verify the link and adjust as needed.
- Sysprep generalizes the image (removes SID, hardware bindings, etc.) making it safe for multi-use deployment.
- The WIM capture uses `/Compress:max` to optimize file size for storage and download efficiency.
- Sysprepped WIM files are compatible with:
  - Windows Deployment Services (WDS)
  - Microsoft Deployment Toolkit (MDT)
  - DISM command-line imaging
  - Hyper-V and VMware VM creation
  - On-premises and cloud deployments
- Build time: typically 2–4 hours depending on Windows updates available and office installation size.

### GitHub Actions workflow details

- **Federated credentials** (`OIDC`): No storage of long-lived secrets; tokens are short-lived and scoped to the repository
- **Role assignments**: GitHub Actions has `Contributor` role on the resource group and subscription
- **Validation step**: Runs `terraform validate` and `packer validate` before attempting build
- **Conditional triggers**: Builds only on changes to `packer/`, `terraform/`, or the workflow file itself
- **Environment protection**: Uses GitHub's `production` environment for optional approval gates

### Troubleshooting

- **Workflow fails at Azure Login**: Verify that `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are set in GitHub repository secrets
- **Packer build times out**: Default Azure VM size is `Standard_D4s_v3`; increase in `packer.pkr.hcl` if needed
- **WIM upload fails**: Check that storage account SAS token is still valid (24-hour default); manually re-run Terraform to generate a fresh token
- **Sysprep hangs**: Packer will timeout after 1 hour by default; adjust `winrm_timeout` in `packer.pkr.hcl` if needed
# packer-win11-test
Create and maintain a clean Windows 11 image 
