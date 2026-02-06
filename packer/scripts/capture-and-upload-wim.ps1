# Capture sysprepped image to WIM and upload to Azure Blob Storage
# This script runs AFTER Sysprep has generalized and rebooted the system
param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,
    
    [Parameter(Mandatory=$true)]
    [string]$SasUrl
)

try {
    Write-Output "[3/4] Capturing sysprepped OS image to WIM..."
    
    $tempDir = "$env:TEMP\wim-export"
    $wimFile = "$tempDir\win11-pro.wim"
    
    # Create temp directory if it doesn't exist
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    # Install DISM/Windows ADK features if not present
    Write-Output "  - Installing Windows ADK features for imaging..."
    Enable-WindowsOptionalFeature -Online -FeatureName "Windows-Foundation" -NoRestart -ErrorAction SilentlyContinue | Out-Null
    
    # Capture the image from the system drive using DISM
    # Use maximum compression to optimize for deployment outside Azure
    Write-Output "  - Capturing C: drive to WIM with maximum compression..."
    
    $dismCmd = @(
        "/Capture-Image",
        "/ImageFile:$wimFile",
        "/CaptureDir:C:\",
        "/Name:Win11-Pro-Custom",
        "/Description:Windows 11 Pro with Office 365 and latest updates (Sysprepped)",
        "/Compress:max"
    )
    
    & dism.exe $dismCmd
    
    if (-not (Test-Path $wimFile)) {
        throw "Failed to capture WIM file"
    }
    
    $wimSizeGB = [math]::Round((Get-Item $wimFile).Length / 1GB, 2)
    Write-Output "  - WIM file created successfully"
    Write-Output "  - File size: $wimSizeGB GB"
    
    # Step 4: Upload optimized WIM to blob storage
    Write-Output "[4/4] Uploading optimized WIM to Azure Blob Storage..."
    Write-Output "  - Storage Account: $StorageAccountName"
    Write-Output "  - Container: $ContainerName"
    
    # Install Azure Storage module if needed
    if (-not (Get-Module Az.Storage -ListAvailable)) {
        Write-Output "  - Installing Az.Storage PowerShell module..."
        Install-Module Az.Storage -Force -Scope CurrentUser -ErrorAction SilentlyContinue
    }
    
    $wimFileName = Split-Path $wimFile -Leaf
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $blobName = "$timestamp-$wimFileName"
    $blobEndpoint = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName$SasUrl"
    
    Write-Output "  - Uploading to: https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
    
    # Upload using Azure Storage REST API
    $fileBytes = [System.IO.File]::ReadAllBytes($wimFile)
    $fileSizeMB = [math]::Round($fileBytes.Length / 1MB, 2)
    
    Write-Output "  - File size to upload: $fileSizeMB MB"
    Write-Output "  - Starting upload..."
    
    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
    }
    
    $progressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $blobEndpoint -Method Put -Headers $headers -Body $fileBytes -UseBasicParsing | Out-Null
    $progressPreference = 'Continue'
    
    Write-Output "  - WIM file uploaded successfully!"
    Write-Output "  - Blob URI: https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Image build and export complete!"
    Write-Output "=========================================="
    Write-Output "WIM file: $blobName"
    Write-Output "Size: $wimSizeGB GB"
    Write-Output "Storage Account: $StorageAccountName"
    Write-Output "Container: $ContainerName"
    Write-Output "=========================================="
    
} catch {
    Write-Error "Capture/Upload failed: $_"
    Exit 1
}
