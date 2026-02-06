# Install PSWindowsUpdate and apply all updates, with reboots as required
Try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot
} Catch {
    Write-Error "Windows Update step failed: $_"
    Exit 1
}
