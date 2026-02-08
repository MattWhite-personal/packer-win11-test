<#PSScriptInfo
 
.VERSION 1.0
 
.GUID 51b341a7-efc2-4eb1-ade5-1b38eb89670e
 
.AUTHOR greg.nottage@microsoft.com
 
.COMPANYNAME Microsoft Corporation
 
.COPYRIGHT Microsoft Corporation. All rights reserved. Licensed under the MIT license. See LICENSE in the project root for license information.
 
.TAGS
 
.LICENSEURI
 
.PROJECTURI
 
.ICONURI
 
.EXTERNALMODULEDEPENDENCIES
 
.REQUIREDSCRIPTS
 
.EXTERNALSCRIPTDEPENDENCIES
 
.RELEASENOTES
 
 
#> 

#Requires -Module PSWindowsUpdate

<#
 
.DESCRIPTION
Automates the PSWindowsUpdate module to install OS updates with logging
 
#>
[CmdLetBinding()]
Param()

$script:BuildVer = "1.0"
$script:ProgramFiles = $env:ProgramFiles
$script:ParentFolder = $PSScriptRoot | Split-Path -Parent
$script:ScriptName = $myInvocation.MyCommand.Name
$script:ScriptName = $scriptName.Substring(0, $scriptName.Length - 4)
$script:LogName = $scriptName + "_" + (Get-Date -UFormat "%d-%m-%Y")
$script:logPath = "$($env:ProgramData)\Microsoft\IntuneApps\$scriptName" 
$script:logFile = "$logPath\$LogName.log"
$script:EventLogName = "Application"
$script:EventLogSource = "EventSystem"
If ($VerbosePreference -eq 'Continue') { Start-Transcript -Path "$logPath\Transcript.log" -Append }
####################################################
####################################################
#Build Functions
####################################################

Function Start-Log {
    param (
        [string]$FilePath,

        [Parameter(HelpMessage = 'Deletes existing file if used with the -DeleteExistingFile switch')]
        [switch]$DeleteExistingFile
    )
        
    #Create Event Log source if it's not already found...
    if ([System.Diagnostics.EventLog]::Exists($script:EventLogName) -eq $false) {
        New-EventLog -LogName $EventLogName -Source $EventLogSource
    }
    if ([System.Diagnostics.EventLog]::SourceExists($script:EventLogSource ) -eq $false) {
        [System.Diagnostics.EventLog]::CreateEventSource($script:EventLogSource , $EventLogName)
    }
    #If (!([system.diagnostics.eventlog]::SourceExists($EventLogSource))) { New-EventLog -LogName $EventLogName -Source $EventLogSource }

    Try {
        If (!(Test-Path $FilePath)) {
            ## Create the log file
            New-Item $FilePath -Type File -Force | Out-Null
        }
            
        If ($DeleteExistingFile) {
            Remove-Item $FilePath -Force
        }
            
        ## Set the global variable to be used as the FilePath for all subsequent Write-Log
        ## calls in this session
        $script:ScriptLogFilePath = $FilePath
    }
    Catch {
        Write-Error $_.Exception.Message
    }
}

####################################################

Function Write-Log {
    #Write-Log -Message 'warning' -LogLevel 2
    #Write-Log -Message 'Error' -LogLevel 3
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
            
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1,

        [Parameter(HelpMessage = 'Outputs message to Event Log,when used with -WriteEventLog')]
        [switch]$WriteEventLog
    )
    Write-Output
    Write-Output $Message
    Write-Output
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    Add-Content -Value $Line -Path $ScriptLogFilePath
    If ($WriteEventLog) { Write-EventLog -LogName $EventLogName -Source $EventLogSource -Message $Message  -Id 100 -Category 0 -EntryType Information }
}

####################################################

Function Invoke-OSUpdates {
    # Enable receive updates for other microsoft products
    Write-Log -Message "Enable receive updates for other microsoft products"
    $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $ServiceManager.ClientApplicationID = "My App"
    $NewService = $ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")

    # Install all available updates, except SilverLight
    Write-Log -Message "Install all available updates, except SilverLight..."
    Get-WuInstall -Install -MicrosoftUpdate -UpdateType Driver -AcceptAll -IgnoreReboot
    Get-WindowsUpdate -Install -NotKBArticleID KB4481252 -IgnoreUserInput -AcceptAll -IgnoreReboot
        
    Write-Log -Message "Install all remaining updates..."
    Get-WuInstall -Install -MicrosoftUpdate -UpdateType Driver -AcceptAll -IgnoreReboot
    Get-WindowsUpdate -Install -NotKBArticleID KB4481252 -IgnoreUserInput -AcceptAll -IgnoreReboot
    $needReboot = Get-WURebootStatus -ComputerName $env:ComputerName -Silent

    Write-Log -Message "Reboot required: $needReboot"

    if ($needReboot) {
        Write-Log -Message "Hard reboot being enforced..."
        # Stop logging
        Stop-Transcript
        Restart-Computer -Force
    }
    else {
        Write-Log -Message "Install all remaining updates..."
        Get-WuInstall -Install -MicrosoftUpdate -UpdateType Driver -AcceptAll -IgnoreReboot
        Get-WindowsUpdate -Install -NotKBArticleID KB4481252 -IgnoreUserInput -AcceptAll -IgnoreReboot
    }
}

Start-Log -FilePath $logFile
Write-Output
Write-Output "Script log file path is [$logFile]" -ForegroundColor Cyan
Write-Output

Write-Output "Looking for local admin rights"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Admin rights detected"
}
else {
    Write-Error "Unable to detect admin rights. Cannot continue"
    Exit 1
}

Write-Log -Message "Starting $ScriptName version $BuildVer" -WriteEventLog
Write-Log -Message "Running from location: $PSScriptRoot" -WriteEventLog
Write-Log -Message "Script log file path is [$logFile]" -WriteEventLog
#endregion Initialisation...
##########################################################################################################
##########################################################################################################

#region Main Script work section
##########################################################################################################
##########################################################################################################
#Main Script work section
##########################################################################################################
##########################################################################################################

Write-Log -Message "Calling Invoke-OSUpdates function..."
Invoke-OSUpdates

Write-Log "$ScriptName completed." -WriteEventLog
If ($VerbosePreference -eq 'Continue') { Stop-Transcript }

##########################################################################################################
##########################################################################################################
#endregion Main Script work section