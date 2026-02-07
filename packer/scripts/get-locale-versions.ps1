# Script to capture current System Locale, Windows Build version and Defender Definition values and output to a local JSON file

$ExecitionStage = $Env:ExecutionStage
$WinUserLanguageList = Get-WinUserLanguageList
$WinSystemLocale = Get-WinSystemLocale
$WinUILanguageOverride = Get-WinUILanguageOverride
$DefenderStatus = Get-MPComputerStatus
$WinBuildInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

$output = [PSCustomObject] @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    WinUserLanguageList = @($WinUserLanguageList | ForEach-Object { @{ LanguageTag = $_.LanguageTag; Autonym = $_.Autonym } })
    WinSystemLocale = @{
        Name = $WinSystemLocale.Name
        LCID = $WinSystemLocale.LCID
    }
    WinUILanguageOverride = $WinUILanguageOverride
    DefenderStatus = @{
        AntivirusEnabled = $DefenderStatus.AntivirusEnabled
        AntiSpywareEnabled = $DefenderStatus.AntiSpywareEnabled
        OnAccessProtectionEnabled = $DefenderStatus.OnAccessProtectionEnabled
        RealTimeProtectionEnabled = $DefenderStatus.RealTimeProtectionEnabled
        DefenderSignaturesOutOfDate = $DefenderStatus.DefenderSignaturesOutOfDate
        AntivirusSignatureVersion = $DefenderStatus.AntivirusSignatureVersion
        AntivirusSignatureLastUpdated = $DefenderStatus.AntivirusSignatureLastUpdated
        AntiSpywareSignatureVersion = $DefenderStatus.AntiSpywareSignatureVersion
        AntiMalwareSignatureVersion = $DefenderStatus.AntiMalwareSignatureVersion
        NisSignatureVersion = $DefenderStatus.NisSignatureVersion
        EngineVersion = $DefenderStatus.EngineVersion
        AMEngineVersion = $DefenderStatus.AMEngineVersion
        AMServiceVersion = $DefenderStatus.AMServiceVersion
        NISEngineVersion = $DefenderStatus.NISEngineVersion
    }
    WinBuildInfo = @{
        ProductName = $WinBuildInfo.ProductName
        CurrentVersion = $WinBuildInfo.CurrentVersion
        CurrentBuild = $WinBuildInfo.CurrentBuild
        DisplayVersion = $WinBuildInfo.DisplayVersion
        ReleaseId = $WinBuildInfo.ReleaseId
        BuildVersion = $WinBuildInfo.LCUVer
    }
}

# Get the script's directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonPath = Join-Path -Path $scriptDir -ChildPath "locale-versions-$ExecutionStage.json"

# Export to JSON file
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

$output | ConvertTo-Json | Write-Host

Write-Host "Locale information exported to: $jsonPath" 