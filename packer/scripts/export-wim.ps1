# Export Windows image to WIM file and upload to Azure blob storage
# Includes Sysprep generalization and optimization for deployment outside Azure
param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,
    
    [Parameter(Mandatory=$true)]
    [string]$SasUrl
)

try {
    Write-Output "Starting WIM export process with Sysprep and optimization..."
    
    $tempDir = "$env:TEMP\wim-export"
    $wimFile = "$tempDir\win11-pro.wim"
    
    # Create temp directory
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    # Step 1: Optimize the image before Sysprep
    Write-Output "[1/4] Optimizing Windows image..."
    
    # Clear temporary files
    Write-Output "  - Clearing temp files..."
    Get-ChildItem -Path "$env:TEMP\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:WINDIR\Temp\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    
    # Clear Windows Update cache
    Write-Output "  - Clearing Windows Update cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    
    # Clear event logs
    Write-Output "  - Clearing event logs..."
    Get-EventLog -LogName * -ErrorAction SilentlyContinue | Clear-EventLog -ErrorAction SilentlyContinue
    
    # Clear DNS cache
    Write-Output "  - Clearing DNS cache..."
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    
    # Disable unnecessary services for golden image
    Write-Output "  - Disabling unnecessary services..."
    $servicesToDisable = @(
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice"     # Device Management Wireless Application Protocol
    )
    foreach ($service in $servicesToDisable) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    }
    
    # Run Disk Cleanup
    Write-Output "  - Running Disk Cleanup..."
    Get-ChildItem -Path "$env:WINDIR\Prefetch\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Step 2: Run Sysprep to generalize the image
    Write-Output "[2/4] Running Sysprep to generalize the image..."
    
    $sysprepPath = "$env:WINDIR\System32\Sysprep\sysprep.exe"
    if (-not (Test-Path $sysprepPath)) {
        throw "Sysprep not found at $sysprepPath"
    }
    
    # Create unattend.xml for Sysprep
    $unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="generalize">
    <component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RemoveAllGeneralizedDevices>true</RemoveAllGeneralizedDevices>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>1</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccount wcm:action="add">
          <Name>Administrator</Name>
          <Group>Administrators</Group>
          <Password>
            <Value>Placeholder123!</Value>
            <PlainText>true</PlainText>
          </Password>
        </LocalAccount>
      </UserAccounts>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <CommandLine>cmd /c "ipconfig /all"</CommandLine>
          <Description>Gather IP config</Description>
          <Order>1</Order>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@
    
    $unattendPath = "$env:TEMP\unattend.xml"
    Set-Content -Path $unattendPath -Value $unattendXml -Encoding UTF8
    
    # Run Sysprep with generalize, oobe, and shutdown flags
    Write-Output "  - Executing: $sysprepPath /generalize /oobe /shutdown /unattend:$unattendPath"
    & $sysprepPath /generalize /oobe /shutdown /unattend:$unattendPath
    
    # Wait for Sysprep to complete and system to shut down
    Write-Output "  - Waiting for Sysprep to complete (this will shut down the VM)..."
    Start-Sleep -Seconds 60
    
    # Note: After Sysprep shutdown, the VM will need to be restarted or reimaged
    # For Packer, this will trigger the next provisioner or build completion
    Write-Output "  - Sysprep completed. System will shut down."
    
} catch {
    Write-Error "Sysprep/Optimization failed: $_"
    Exit 1
}
    
    # Upload to blob storage
    Write-Output "Uploading WIM to Azure Blob Storage..."
    Write-Output "Storage Account: $StorageAccountName"
    Write-Output "Container: $ContainerName"
    
    # Install Azure Storage module if needed
    if (-not (Get-Module Az.Storage -ListAvailable)) {
        Install-Module Az.Storage -Force -Scope CurrentUser
    }
    
    $wimFileName = Split-Path $wimFile -Leaf
    $blobEndpoint = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$wimFileName$SasUrl"
    
    Write-Output "Uploading to: $blobEndpoint"
    
    # Use AzCopy or native PowerShell to upload
    $uri = [System.Uri]::new($blobEndpoint)
    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
    }
    
    # Upload using Azure Storage REST API
    $fileBytes = [System.IO.File]::ReadAllBytes($wimFile)
    Invoke-WebRequest -Uri $blobEndpoint -Method Put -Headers $headers -Body $fileBytes -UseBasicParsing
    
    Write-Output "WIM file uploaded successfully to $blobEndpoint"
    Write-Output "Export and upload complete!"
    
} catch {
    Write-Error "Export-WIM failed: $_"
    Exit 1
}
