# Install en-GB fully
Install-Language -Language en-GB -CopyToSettings -Verbose

# Remove en-US
Uninstall-Language -Language en-US -Verbose

# Set system locale, culture, and UI
Set-WinSystemLocale en-GB
Set-Culture en-GB
Set-WinUILanguageOverride en-GB
Set-WinUserLanguageList en-GB -Force
