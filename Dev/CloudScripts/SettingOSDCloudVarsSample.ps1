<# 
Sample Script of setting OSDCloud Variables, then triggering OSDCloud using "Start-OSDCloud"
The values you set in the global variable "MyOSDCloud" will be read in by OSDCloud process and applied.

Feel free to make a copy of this script and modify the variables.
If you know to know a full list of variables, look here: https://github.com/OSDeploy/OSD/blob/master/Public/OSDCloud.ps1

#>


$ScriptName = 'sample.garytown.com'
$ScriptVersion = '24.01.01.03'
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

#Testing Custom Images
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


#Testing MS Update Catalog Driver Sync
#$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

#Used to Determine Driver Pack
$Product = (Get-MyComputerProduct)
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#If Drivers are expanded on the USB Drive, disable installing a Driver Pack
if (Test-DISMFromOSDCloudUSB -eq $true){
    Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
    if ($Global:MyOSDCloud.SyncMSUpCatDriverUSB -eq $true){
        $Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'
    }
    else {
        $Global:MyOSDCloud.DriverPackName = "None"
    }
}
#>

#Enable HPIA | Update HP BIOS | Update HP TPM
if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    $Global:MyOSDCloud.HPIAALL = [bool]$true
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true

}



#write variables to console
$Global:MyOSDCloud

#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
import-module "$ModulePath\OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

write-host "OSDCloud Process Complete, Running Custom Actions Before Reboot" -ForegroundColor Green
if (Test-DISMFromOSDCloudUSB){
    Start-DISMFromOSDCloudUSB
}


#Restart Computer from WInPE into Full OS to continue Process
restart-computer
