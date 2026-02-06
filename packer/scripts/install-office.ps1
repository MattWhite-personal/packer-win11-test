# Install Microsoft 365 Apps for Enterprise using Office Deployment Tool (ODT)
# Downloads the latest ODT by parsing the official Microsoft download page
# Uses configuration XML from C:\build-scripts\odt.xml

$ErrorActionPreference = "Stop"

Write-Output "=== Starting Office installation via ODT ==="

# Ensure TLS 1.2 (critical for Microsoft endpoints)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Working directory
$temp = Join-Path $env:TEMP "odt"
New-Item -Path $temp -ItemType Directory -Force | Out-Null

$odtExe = Join-Path $temp "OfficeDeploymentTool.exe"
$odtPage = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"

Write-Output "Fetching Office Deployment Tool download page..."
$page = Invoke-WebRequest -Uri $odtPage -UseBasicParsing

# Find the actual EXE download link
$downloadLink = ($page.Links |
    Where-Object {
        $_.href -match "officedeploymenttool.*\.exe"
    } |
    Select-Object -First 1).href

if (-not $downloadLink) {
    throw "Failed to locate Office Deployment Tool download URL on page."
}

# Handle relative URLs just in case
if ($downloadLink -notmatch "^https?://") {
    $downloadLink = "https://www.microsoft.com$downloadLink"
}

Write-Output "Downloading Office Deployment Tool from:"
Write-Output $downloadLink

Invoke-WebRequest -Uri $downloadLink -OutFile $odtExe -UseBasicParsing

# Extract ODT
Write-Output "Extracting Office Deployment Tool..."
Start-Process -FilePath $odtExe `
    -ArgumentList "/quiet", "/extract:$temp" `
    -NoNewWindow `
    -Wait

$setupExe = Join-Path $temp "setup.exe"
if (-not (Test-Path $setupExe)) {
    throw "ODT extraction failed: setup.exe not found."
}

# Office configuration file
$configPath = "C:\build-scripts\odt.xml"
if (-not (Test-Path $configPath)) {
    throw "Office configuration file not found at $configPath"
}

Write-Output "Using Office configuration file:"
Write-Output $configPath

# Start Office installation
Write-Output "Starting Office installation (this can take several minutes)..."
Start-Process -FilePath $setupExe `
    -ArgumentList "/configure", "`"$configPath`"" `
    -NoNewWindow `
    -Wait

Write-Output "=== Office installation completed successfully ==="
