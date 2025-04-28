<#

OSDCloud Wrapper Script Example Script
This will set the variables used by OSDCloud, update the MS Surface Drivers Catalog, then start OSDCloud, along with do a few things after

you can edit your OSDCloud Boot Media to automatically start this by hosting this on GitHub, and modifying your boot image like:


Edit-OSDCloudWinPE -StartURL "https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Folinic.ps1"


3 Regions in script

Pre OSDCloud
Start OSDCloud
Post OSDCloud

Pre OSDCloud is for setting variables, updating BIOS Settings, etc

Start OSDCloud, you can change your command line, but really nothing to do here

Post OSDCloud, this is where you can do a lot of extra customization to your Offline Windows, call scripts to remove AppX packages, slip in a CU, inject files,
 - Add Additional PowerShell Modules
 - Add a custom SetupComplete file (do not overwrite the one OSDCloud creates, use the custom path that OSDCloud would trigger)
 - Add OEM Specific stuff
 - Remove built in Items
 - Apply CU / SSU / etc offline before rebooting
 - Add Custom wallpapers
 - Edit the Offline Registry
 - SO MANY THINGS
 - Finally reboot


#>

write-host "-------------------------------------------------" -ForegroundColor Cyan
write-host "Starting Custom OSDCloud Wrapper" -ForegroundColor Cyan
write-host "-------------------------------------------------" -ForegroundColor Cyan
Write-Host ""


#region Tasks to run in WinPE before triggering OSD Cloud

#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'


#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$false
}

#Disable OSDCloud from auto downloading and applying drivers
$Global:MyOSDCloud.DriverPackName = "None"

#write variables to console
Write-Host "Pre-Set Varariables for OSDCloud" -ForegroundColor Green
Write-Output $Global:MyOSDCloud
Write-Host ""
Write-Host "Updating Surface Driver Catalog..." -ForegroundColor Cyan
iex (irm "https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/Catalogs/Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1")
Update-OSDCloudSurfaceDriverCatalogJustInTime


#endregion

#region OSDCloud

#Launch OSDCloud
Write-Host "Starting OSDCloud on $Manufacturer $Model $Product" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage" -ForegroundColor Green

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

write-host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Green

#endregion

#region Post OSDCloud, do more things in WinPE before you reboot.

#Copy CMTrace Local:(I always add CMTrace to my boot images)
if (Test-path -path "x:\windows\system32\cmtrace.exe"){
    copy-item "x:\windows\system32\cmtrace.exe" -Destination "C:\Windows\System\cmtrace.exe" -verbose
}

#If Lenovo, add the Lenovo Module
if ($Manufacturer -match "Lenovo") {
    $PowerShellSavePath = 'C:\Program Files\WindowsPowerShell'
    Write-Host "Copy-PSModuleToFolder -Name LSUClient to $PowerShellSavePath\Modules"
    Copy-PSModuleToFolder -Name LSUClient -Destination "$PowerShellSavePath\Modules"
}

#Restart Computer After OSDCloud is complete in WinPE
Restart-Computer

#endregion
