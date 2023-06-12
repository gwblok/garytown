<# Gary Blok | @gwblok | GARYTOWN.COM
.SYNOPSIS
    HP Dock Updater Script for use with ConfigMgr App Model
.DESCRIPTION
    Detects which dock is detected and will update the Firmware for the Dock.
    IF scripts detects HPCMSL, it will also create a notification for the end user after update is staged / completed.

    Script will first do a check to confirm update is required.
.NOTES
    File Name      : CM_AppModel_DockUpdaterScript.ps1
    
.LINK
    Related Posts: https://garytown.com/hp-dock-configmgr-global-condition
    Related Posts: 

.Parameter UIExpereince. choose silent to have completely hidden or NonInterative to show dialog of progress

.Parameter Stage, if option to stage firmware is available for the dock model, it will stage the firmware for install on disconnect instead of installing imediately

.Parameter Notifications, if HPCMSL is detected, this switch will display notifiations after the staging or installing of the firmware to alert the user of the status.


.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -File CM_AppModel_DockUpdaterScript.ps1
    This will run the script with the defaults of staging the firmware on docks that support that function, and updating the docks real time on the rest.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -File CM_AppModel_DockUpdaterScript.ps1 -UIExperience NonInteractive -Stage:$false
    This will set the Updates to run real time for all dock upgrades, even if they support staging.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -File CM_AppModel_DockUpdaterScript.ps1 -UIExperience NonInteractive -Stage:$false
    This will set the Updates to run real time for all dock upgrades, even if they support staging.
      
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][ValidateSet('NonInteractive', 'Silent')][String]$UIExperience,
    [switch]$Stage = $true, #Set by default to True for Models that support Stage.  If you want to not stage updates but trigger it ASAP, set to false
    [switch]$Notifications    
) # param

function Get-HPDockInfo {
    $pPnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 
    # **** Hardcode URLs in case of no CMSL installed: ****
    $Url_TBG2 = 'ftp.hp.com/pub/softpaq/sp143501-144000/sp143977.exe'   #  (as of apr 6, 2023)
    $Url_TBG4 = 'ftp.hp.com/pub/softpaq/sp143501-144000/sp143669.exe'   #  (as of apr 6, 2023)
    $Url_UniG2 = 'ftp.hp.com/pub/softpaq/sp146001-146500/sp146291.exe'  #  (as of june 6, 2023)
    $Url_UsbG5 = 'ftp.hp.com/pub/softpaq/sp146001-146500/sp146273.exe'  #  (as of june 6, 2023)
    $Url_UsbG4 = 'ftp.hp.com/pub/softpaq/sp88501-89000/sp88999.exe'     #  (as of apr 6, 2023)
    $Url_EssG5 = 'ftp.hp.com/pub/softpaq/sp144501-145000/sp144502.exe'  #  (as of apr 6, 2023)

    #######################################################################################
    $Dock_Attached = 0      # default: no dock found
    $Dock_ProductName = $null
    $Dock_Url = $null   
    # Find out if a Dock is connected - assume a single dock, so stop at first find
    foreach ( $iDriver in $pPnpSignedDrivers ) {
        $f_InstalledDeviceID = "$($iDriver.DeviceID)"   # analyzing current device
        if ( ($f_InstalledDeviceID -match "HID\\VID_03F0") -or ($f_InstalledDeviceID -match "USB\\VID_17E9") ) {
            switch -Wildcard ( $f_InstalledDeviceID ) {
                '*PID_0488*' { $Dock_Attached = 1 ; $Dock_ProductName = 'HP Thunderbolt Dock G4' ; $Dock_Url = $Url_TBG4 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe'}
                '*PID_0667*' { $Dock_Attached = 2 ; $Dock_ProductName = 'HP Thunderbolt Dock G2' ; $Dock_Url = $Url_TBG2 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
                '*PID_484A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP USB-C Dock G4' ; $Dock_Url = $Url_UsbG4 ; $FirmwareInstaller = 'HP_USB-C_Dock_G4_FW_Update_Tool_Console.exe' }
                '*PID_046B*' { $Dock_Attached = 4 ; $Dock_ProductName = 'HP USB-C Dock G5' ; $Dock_Url = $Url_UsbG5  ; $FirmwareInstaller = 'HPFirmwareInstaller.exe'}
                #'*PID_600A*' { $Dock_Attached = 5 ; $Dock_ProductName = 'HP USB-C Universal Dock' }
                '*PID_0A6B*' { $Dock_Attached = 6 ; $Dock_ProductName = 'HP USB-C Universal Dock G2' ; $Dock_Url = $Url_UniG2 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
                '*PID_056D*' { $Dock_Attached = 7 ; $Dock_ProductName = 'HP E24d G4 FHD Docking Monitor' }
                '*PID_016E*' { $Dock_Attached = 8 ; $Dock_ProductName = 'HP E27d G4 QHD Docking Monitor' }
                '*PID_379D*' { $Dock_Attached = 9 ; $Dock_ProductName = 'HP USB-C G5 Essential Dock' ; $Dock_Url =  $Url_EssG5 ; $FirmwareInstaller = 'HPFirmwareInstaller.exe' }
            } # switch -Wildcard ( $f_InstalledDeviceID )
        } # if ( $f_InstalledDeviceID -match "VID_03F0")
        if ( $Dock_Attached -gt 0 ) { break }
    } # foreach ( $iDriver in $gh_PnpSignedDrivers )
    #######################################################################################

    return @(
        @{Dock_Attached = $Dock_Attached ;  Dock_ProductName = $Dock_ProductName  ;  Dock_Url = $Dock_Url;  Dock_InstallerName = $FirmwareInstaller}
    )
} # function Get-HPDockInfo


function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

 $HPFIrmwareUpdateReturnValues = @(
            @{Code = "0" ;  Message = "Success"}
            @{Code = "101" ;  Message = "Install or stage failed. One or more firmware failed to install."}
            @{Code = "102" ;  Message = "Configuration file failed to be loaded.This may be because it could not be found or that it was not properly formatted."}
            @{Code = "103" ;  Message = "One or more firmware packages specified in the configuration file could not be loaded."}
            @{Code = "104" ;  Message = "No devices could be communicated with.This could be because necessary drivers are missing to detect the device."}
            @{Code = "105" ;  Message = "Out - of - date firmware detected when running with 'check' flag."}
            @{Code = "106" ;  Message = "An instance of HP Firmware Installer is already running"}
            @{Code = "107" ;  Message = "Device not connected.This could be because PID or VID is not detected."}
            @{Code = "108" ;  Message = "Force option disabled.Firmware downgrade or re - flash not possible on this device."}
            @{Code = "109" ;  Message = "The host is not able to update firmware"}
        )

$DockInfo = Get-HPDockInfo
$URL = $DockInfo.Dock_Url
$SPEXE = ($URL.Split("/") | Select-Object -Last 1)
$SPNumber = ($URL.Split("/") | Select-Object -Last 1).replace(".exe","")
$FirmwareInstallerName = $DockInfo.Dock_InstallerName
$CachePath = Get-ScriptDirectory


try 
    {
    Get-HPDeviceDetails | Out-Null
    $HPCMSL = $true
}
catch {$HPCMSL = $false}


# Create Required Folders
$OutFilePath = "$env:SystemDrive\swsetup\dockfirmware"
$ExtractPath = "$OutFilePath\$SPNumber"
try {
    [void][System.IO.Directory]::CreateDirectory($OutFilePath)
    [void][System.IO.Directory]::CreateDirectory($ExtractPath)
} 
catch { throw }
#Extract Softpaq if it isn't already there.
if (!(Test-Path "$OutFilePath\$SPNumber\$FirmwareInstallerName")){
    $Extract = Start-Process -FilePath "$CachePath\$SPEXE" -ArgumentList "/s /e /f $ExtractPath" -NoNewWindow -PassThru -Wait
}
#If still not there, must have failed to extract
if (!(Test-Path "$OutFilePath\$SPNumber\$FirmwareInstallerName")){
    throw
}

#Set Firmware Install Params
if (!($UIExperience)){$UIExperience = 'NonInteractive'} #Default to Non-Interactive if nothing set (unless using Stage, then sets to silent)
    $Mode = switch ($UIExperience)
    {
        "NonInteractive" {"-ni"}
        "Silent" {"-s"}
        "Check" {"-C"}
        "Force" {"-f"}
    }


#Set Update to Stage if request & if supported
if ($Stage){
    if ($DockInfo.Dock_Attached -in (1, 4, 6)){#supports USB-C Dock G5 & HP USB-C Universal Dock G2 & HP Thunderbolt Dock G4
        $FirmwareArgList = "-s -stage"
        $StageEnabled = $true
        $Notifications = $true  #Enable notifications automatically when Firmware has been staged
    }
    else {
        $FirmwareArgList = "$Mode"
    }
}
else {
    $FirmwareArgList = "$Mode"
}

#Run Firmware Check
$HPFirmwareCheck = Start-Process -FilePath "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe" -ArgumentList "-c" -PassThru -Wait -NoNewWindow

if ($HPFirmwareCheck.ExitCode -eq 105){ #Firmware requires Update

    #Run the FIrmware Update
    $HPFirmwareUpdate = Start-Process -FilePath "$OutFilePath\$SPNumber\HPFirmwareInstaller.exe" -ArgumentList "$FirmwareArgList" -PassThru -Wait -NoNewWindow

    #Create Notifications if HPCMSL is on device & Notications enabled via Parameters
    if ($HPFirmwareUpdate.ExitCode -eq "0" -and $HPCMSL -eq $true -and $Notifications -eq $true){
        if ($StageEnabled){
            Invoke-RebootNotification -Title 'HP Dock Disconnect Required' -Message "The Dock Firmware has been staged for update, please DISCONNECT your dock at the end of the day"
        }
        else {
            Invoke-RebootNotification -Title 'HP Dock Updated' -Message "The Dock Firmware has been Updated, recommend rebooting at the end of the day"
        }
    } 

    Exit $HPFirmwareUpdate.ExitCode
}
else {
    Exit $HPFirmwareCheck.ExitCode
}
