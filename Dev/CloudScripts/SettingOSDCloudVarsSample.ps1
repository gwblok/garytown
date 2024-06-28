<# 
Sample Script of setting OSDCloud Variables, then triggering OSDCloud using "Start-OSDCloud"
The values you set in the global variable "MyOSDCloud" will be read in by OSDCloud process and applied.

The start of the script, you can do pre-setup on your device
 - Modify BIOS Settings
 - Set or Remove a BIOS Password
 - Wipe drive (OSDCloud will do this anyway)
 - Set OSDCloud Variables

The end of the script is after OSDCloud has run, but before it reboots into the OS (assuming you set the variable to not have OSDCloud reboot your device)
 - This is handy for running any extra OS modifications while offline
   - Remove Built in Apps
   - Add additional drivers via DISM
   - Add offline features / language packs
   - whatever you want to do, be creative

Feel free to make a copy of this script and modify the variables.
If you know to know a full list of variables, look here: https://github.com/OSDeploy/OSD/blob/master/Public/OSDCloud.ps1

#>


$ScriptName = 'sample.garytown.com'
$ScriptVersion = '24.06.28.01'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"





#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'


#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$false  #Disables OSDCloud automatically restarting
    RecoveryPartition = [bool]$true #Ensures a Recover partition is created, True is default unless on VM
    OEMActivation = [bool]$True #Attempts to look up the Windows Code in UEFI and activate Windows OS (SetupComplete Phase)
    WindowsUpdate = [bool]$true #Runs Windows Updates during Setup Complete
    WindowsUpdateDrivers = [bool]$true #Runs WU for Drivers during Setup Complete
    WindowsDefenderUpdate = [bool]$true #Run Defender Platform and Def updates during Setup Complete
    SetTimeZone = [bool]$False #Set the Timezone based on the IP Address
    ClearDiskConfirm = [bool]$False #Skip the Confirmation for wiping drive before format
    ShutdownSetupComplete = [bool]$true #After Setup Complete, instead of Restarting to OOBE, just Shutdown
    SyncMSUpCatDriverUSB = [bool]$true #Sync any MS Update Drivers during WinPE to Flash Drive, saves time in future runs
}

#Testing Custom Images - Use this if you want to automate using your own WIM / ESD file
#Region Custom Image
$ESDName = '22621.382.220806-0833.ni_release_svc_refresh_CLIENTCONSUMER_RET_x64FRE_en-us.esd'
$ImageFileItem = Find-OSDCloudFile -Name $ESDName  -Path '\OSDCloud\OS\'
if ($ImageFileItem){
    $ImageFileItem = $ImageFileItem | Where-Object {$_.FullName -notlike "C*"} | Where-Object {$_.FullName -notlike "X*"} | Select-Object -First 1
    if ($ImageFileItem){
        $ImageFileName = Split-Path -Path $ImageFileItem.FullName -Leaf
        $ImageFileFullName = $ImageFileItem.FullName
        
        $Global:MyOSDCloud.ImageFileItem = $ImageFileItem
        $Global:MyOSDCloud.ImageFileName = $ImageFileName
        $Global:MyOSDCloud.ImageFileFullName = $ImageFileFullName
        $Global:MyOSDCloud.OSImageIndex = 9 #Pro
    }
}
#endregion Custom Image

#Testing MS Update Catalog Driver Sync
#$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

<# 
Used to Determine Driver Pack - OSDCloud will natively do this, so you don't have to, but..
I want to control exactly how drivers are being done, what I'm doing here is..
- Search for Driver Pack, if found, populate the driver pack variable information used in OSDCloud
- Check to see if I have driver packs already downloaded and extracted into the DISM folder on the OSDCloudUSB
  - If I do, Check if I'm wanting to Sync the MS Update Catalog drivers to the USB (Set above), because then I assume I want it to use the MS Catalog to suppliment my own drivers
  - If I do want to sync, set the OSDCloud driver pack variables to use the Microsoft Update Catalog
  - if I don't, set the driver pack to none, so it will ONLY use the drivers I have extracted into my DISM folder on the OSDCloudUSB
#>
#Region Determine if using native driver packs, or if I want to use extracted drivers on OSDCloudUSB
$Product = (Get-MyComputerProduct)
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#If Drivers are expanded on the USB Drive, disable installing a Driver Pack
if ((Test-DISMFromOSDCloudUSB) -eq $true){
    Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
    if ($Global:MyOSDCloud.SyncMSUpCatDriverUSB -eq $true){
        $Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'
    }
    else {
        $Global:MyOSDCloud.DriverPackName = "None"
    }
}
#endregion Driver Pack Stuff


#Enable HPIA | Update HP BIOS | Update HP TPM
if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    $Global:MyOSDCloud.HPIAALL = [bool]$true
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true

}



#write variables to console
$Global:MyOSDCloud

<#
Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
This would be if YOU did any modifications to OSDCloud code yourself, and you want to import that before running OSDCloud.
I often do this when I'm developing new features that aren't in the module yet.
#>

#$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
#import-module "$ModulePath\OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

#Anything at this point will now run after OSDCloud WinPE stage is complete, so if you want to make any additional modifications to the OS while Offline, this is when you do it:


<#This is now native in OSDCloud
write-host "OSDCloud Process Complete, Running Custom Actions Before Reboot" -ForegroundColor Green
if (Test-DISMFromOSDCloudUSB){
    Start-DISMFromOSDCloudUSB
}
#>

#Restart Computer from WInPE into Full OS to continue Process
restart-computer
