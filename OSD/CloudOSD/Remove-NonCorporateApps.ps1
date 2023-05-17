#Requires -Version 5.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Remove non-enterprise worthy apps

.DESCRIPTION
Given a list of apps, remove if found on local machine

.LINK 
http://www.vacuumbreather.com/index.php/blog/item/51-windows-10-1709-built-in-apps-what-to-keep

.LINK 
https://blogs.technet.microsoft.com/mniehaus/2015/11/11/removing-windows-10-in-box-apps-during-a-task-sequence/

.LINK 
https://blogs.technet.microsoft.com/mniehaus/2015/11/23/seeing-extra-apps-turn-them-off/


Original Script by Keith Garner
Modified by Gary Blok (@GWBLOK)

22.02.23.01
 - Removed Parameters so it would work via Invoke-RestMethod
 - Added Logic to be able to run in WinPE to remove items offline & again online to clean up the rest... expect errors in logs.
#>


$results = @()
$Capabilities = @(
    "App.Support.ContactSupport"
    "App.Support.QuickAssist"
)
$apps += @(
        "Microsoft.3DBuilder"
        #"Microsoft.MSPaint"
        "Microsoft.Print3D"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.Office.OneNote"
        "Microsoft.OneConnect"
        "Microsoft.People"
        "Microsoft.SkypeApp"
        #"Microsoft.StorePurchaseApp"
        "Microsoft.windowscommunicationsapps"
        #"Microsoft.WindowsStore"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.Advertising.Xaml"
        #"Microsoft.Getstarted"
        #"Microsoft.GetHelp"
        "Microsoft.Messaging"
        #"Microsoft.WindowsFeedbackHub"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
)


#region argument parsing and logging

if ( -not ( get-module DISM ) ) { import-module DISM }

try {
    $ts = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
    $InWinPE = $ts.value('_SMSTSInWinPE')
    if ($ts.Value("LogPath") -ne "") {
        $LogPath = $ts.Value("LogPath") + "\RemoveApps.Log"   #MDT
        Write-Host "Running within TS, Set $LogPath"
    }
    elseif ($ts.Value("_SMSTSLogPath") -ne "") {
        $LogPath = $ts.Value("_SMSTSLogPath") + "\RemoveApps.Log"  #SCCM
        Write-Host "Running within TS, Set $LogPath"
    }
    else{
        $LogPath = $env:TEMP + "\RemoveApps.Log"  #Temp
        Write-Host "Can't find TS Var for Logs, Set $LogPath"
    }
        
}
catch {
    $LogPath = $env:TEMP + "\RemoveApps.Log"
    Write-Host "Can't find TS Var for Logs, Set $env:TEMP\RemoveApps.log"

    
}
Write-Output "LogPath: $LogPath"

write-verbose "New DISM LogLevel [3]  LogPath: $LogPath"
if ( $Path ) {
    $DISMArgs = @{ Path = $Path; LogLevel = [Microsoft.Dism.Commands.LogLevel]::WarningsInfo ;  LogPath = $LogPath }
}
elseif ( $env:SYSTEMDRIVE -eq "X:" ) {
    # RUnning offline in WinPE.

    $Path = get-volume | 
        ? DRiveType -eq 'Fixed' | 
        ? DriveLetter -ne 'x' | 
        ? FileSystem -eq 'NTFS' | 
        ? { test-path "$($_.DriveLetter):\Windows\System32" } | 
        %{ "$($_.DriveLetter):\" }

    $DISMArgs = @{ Path = $Path; LogLevel = [Microsoft.Dism.Commands.LogLevel]::WarningsInfo ;  LogPath = $LogPath }
}
else {
    $DISMArgs = @{ Online = $True; LogLevel = [Microsoft.Dism.Commands.LogLevel]::WarningsInfo ;  LogPath = $LogPath }
}

$DISMArgs | out-string -Width 120 | write-verbose

#endregion

#region Remove Provisioned Windows Apps

write-verbose "Remove Provisioned Windows Apps"

$results += Get-AppxProvisionedPackage  @DISMArgs | 
    Where-Object { $TestName = $_.DisplayName; $Apps | ? { $TestName -match $_ } } | 
    Remove-AppxProvisionedPackage @DismArgs

#endregion

#region Remove Installed Windows Apps
if ($InWinPE -ne "TRUE"){
    write-verbose "Remove Installed Windows Apps"

    $results += Get-AppxPackage | 
        Where-Object { $TestName = $_.Name; $Apps | ? { $TestName -match $_ } } |
        Remove-AppxPackage
    }
#endregion

#region Remove Windows Capability

write-verbose "Remove Windows Capability"

$results += & dism.exe /online /get-capabilities /limitaccess | 
    Where-Object { $_ -match ".* (([^ \~]*)\~[^ ]*)$" } | 
    Where-Object { $Matches[2] -in $Capabilities } | 
    ForEach-Object { write-host "remove $Matches[1]" ; Remove-WindowsCapability @DISMArgs -Name $Matches[1] }

#endregion

#region Cleanup

write-verbose "cleanup"

if ( $true -in $results.restartneeded ) {

    $results | Out-string -Width 120 | write-verbose

    write-verbose "whoops, we need a reboot!"
    exit 3010

}

#endregion
