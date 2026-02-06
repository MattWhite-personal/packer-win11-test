# Install Microsoft 365 Apps for Enterprise using Office Deployment Tool (ODT)
# This script downloads the ODT, places a configuration XML next to it, and runs setup.exe /configure

$temp = "$env:TEMP\\odt"
New-Item -Path $temp -ItemType Directory -Force | Out-Null

$odtZip = "$temp\\odt.exe"
$odtUrl = "https://download.microsoft.com/download/3/1/9/3196D9C9-3C2D-4A2C-966E-7B5E3AA0C0B4/OfficeDeploymentTool.exe"

Write-Output "Downloading Office Deployment Tool..."
Invoke-WebRequest -Uri $odtUrl -OutFile $odtZip -UseBasicParsing

Write-Output "Extracting ODT..."
Start-Process -FilePath $odtZip -ArgumentList "/quiet","/extract:$temp" -Wait

$configPath = Join-Path $temp "config.xml"
if (-not (Test-Path $configPath)) {
    Copy-Item -Path (Join-Path $PSScriptRoot "odt.xml") -Destination $configPath -Force
}

Write-Output "Starting Office installation (this may take a while)..."
Start-Process -FilePath (Join-Path $temp "setup.exe") -ArgumentList "/configure","$configPath" -Wait

Write-Output "Office installation finished."
