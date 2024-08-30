<#

OSDCloud Wrapper Script
This will set the variables used by OSDCloud, update the MS Surface Drivers Catalog, then start OSDCloud, along with do a few things after

you can edit your OSDCloud Boot Media to automatically start this by hosting this on GitHub, and modifying your boot image like:


Edit-OSDCloudWinPE -StartURL "https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Hope.ps1"



#>

write-host "-------------------------------------------------" -ForegroundColor Cyan
write-host "Starting Custom OSDCloud Wrapper" -ForegroundColor Cyan
write-host "-------------------------------------------------" -ForegroundColor Cyan
Write-Host ""



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


#write variables to console
Write-Host "Pre-Set Varariables for OSDCloud" -ForegroundColor Green
Write-Output $Global:MyOSDCloud
Write-Host ""
Write-Host "Updating Surface Driver Catalog..." -ForegroundColor Cyan
iex (irm "https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/Catalogs/Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1")
Update-OSDCloudSurfaceDriverCatalogJustInTime


#Launch OSDCloud
Write-Host "Starting OSDCloud on $Manufacturer $Model $Product" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage" -ForegroundColor Green

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

write-host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Green



#Copy CMTrace Local:(I always add CMTrace to my boot images)
if (Test-path -path "x:\windows\system32\cmtrace.exe"){
    copy-item "x:\windows\system32\cmtrace.exe" -Destination "C:\Windows\System\cmtrace.exe" -verbose
}

#Restart Computer After OSDCloud is complete in WinPE
Restart-Computer
