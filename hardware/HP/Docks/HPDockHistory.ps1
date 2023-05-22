
<#
 .Author 
  Gary Blok | HP Inc | @gwblok | GARYTOWN.COM
  Dan Felman | HP Inc | @dan_felman 
 
 .Synopsis
  Checks for Connected HP Dock and Logs information to Registry

 .Description
  Will scan for Hardware ID of HP Dock, then write information to 
  HKLM:\SOFTWARE\HP\HP Dock History, using the Name of the Dock & Tagging the Date it was connected
#>

function Get-HPDockInfo {
    [CmdletBinding()]
    param($pPnpSignedDrivers)

    # **** Hardcode URLs in case of no CMSL installed: ****
    $Url_TBG2 = 'ftp.hp.com/pub/softpaq/sp143501-144000/sp143977.exe'   #  (as of apr 6, 2023)
    $Url_TBG4 = 'ftp.hp.com/pub/softpaq/sp143501-144000/sp143669.exe'   #  (as of apr 6, 2023)
    $Url_UniG2 = 'ftp.hp.com/pub/softpaq/sp143001-143500/sp143451.exe'  #  (as of apr 6, 2023)
    $Url_UsbG5 = 'ftp.hp.com/pub/softpaq/sp143001-143500/sp143343.exe'  #  (as of apr 6, 2023)
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

$AdminRights = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ( $DebugOut ) { Write-Host "--Admin rights:"$AdminRights }

$PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 
$Dock = Get-HPDockInfo $PnpSignedDrivers
$DockRegPath = 'HKLM:\SOFTWARE\HP\HP Dock History'
# lop for up to 10 secs in case we just powered-on, or Dock detection takes a bit of time
[int]$Counter = 0
[int]$StepAmt = 20
if ( $Dock.Dock_Attached -eq 0 ) {
if ( $DebugOut ) { Write-Host "Waiting for Dock to be fully attached up to $WaitTimer seconds" -ForegroundColor Green }
do {
    if ( $DebugOut ) { Write-Host " Waited $Counter Seconds Total.. waiting additional $StepAmt" -ForegroundColor Gray}
    $counter += $StepAmt
    Start-Sleep -Seconds $StepAmt
$PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver
    $Dock = Get-HPDockInfo $PnpSignedDrivers
    if ( $counter -eq $WaitTimer ) {
        if ( $DebugOut ) { Write-Host "Waited $WaitTimer Seconds, no dock found yet..." -ForegroundColor Red}
    }
}
while ( ($counter -lt $WaitTimer) -and ($Dock.Dock_Attached -eq "0") )
} # if ( $Dock.Dock_Attached -eq "0" )

if ( $Dock.Dock_Attached -eq 0 ) {
Write-Host " No dock attached" -ForegroundColor Green
} 
else {
if (!(Test-Path -Path $DockRegPath)){New-Item -Path $DockRegPath | Out-Null}
New-ItemProperty -Path $DockRegPath -Name "$($Dock.Dock_ProductName)" -Value $(Get-Date -Format "yyyy/MM/dd HH:mm:ss") -PropertyType string -Force | Out-Null

}