Try {
    #Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
} Catch {
    Write-Error "Module install step failed: $_"
    Exit 1
}