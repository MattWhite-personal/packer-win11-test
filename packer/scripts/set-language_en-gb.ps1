# Install en-GB fully
Write-Host "Installing EN-GB Language Pack"
Install-Language -Language en-GB -CopyToSettings -Verbose

# Remove en-US
#Uninstall-Language -Language en-US -Verbose

# Set system locale, culture, and UI
Write-Host "Setting Locale settings"
Set-WinSystemLocale en-GB
Set-Culture en-GB
Set-WinUILanguageOverride en-GB
Set-WinUserLanguageList en-GB -Force

Get-WinSystemLocale
Get-Culture
Get-WinUserLanguageList
Write-Host "------- DONE LANGUAGE -------"