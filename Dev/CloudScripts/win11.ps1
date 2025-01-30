#to Run, boot OSDCloudUSB, at the PS Prompt: iex (irm win11.garytown.com)

#region Initialization
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}
function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}
function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray '========================================================================='
}
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}
function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#endregion

$ScriptName = 'win11.garytown.com'
$ScriptVersion = '25.01.22.1'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"
#iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
#iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

<# Offline Driver Details
If you extract Driver Packs to your Flash Drive, you can DISM them in while in WinPE and it will make the process much faster, plus ensure driver support for first Boot
Extract to: OSDCLoudUSB:\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct
Use OSD Module to determine Vars
$ComputerProduct = (Get-MyComputerProduct)
$ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
#>



#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 24H2 x64'
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
    CheckSHA1 = [bool]$true
}

#Testing MS Update Catalog Driver Sync
#$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}
#$Global:MyOSDCloud.DriverPackName = "None"

<#If Drivers are expanded on the USB Drive, disable installing a Driver Pack
if (Test-DISMFromOSDCloudUSB -eq $true){
    Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
    if ($Global:MyOSDCloud.SyncMSUpCatDriverUSB -eq $true){
        write-host "Setting DriverPackName to 'Microsoft Update Catalog'"
        $Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'
    }
    else {
        write-host "Setting DriverPackName to 'None'"
        $Global:MyOSDCloud.DriverPackName = "None"
    }
}
#>
#Enable HPIA | Update HP BIOS | Update HP TPM
 
if (Test-HPIASupport){
    Write-SectionHeader -Message "Detected HP Device, Enabling HPIA, HP BIOS and HP TPM Updates"
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    if ($Product -ne '83B2' -and $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
    #{$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    #$Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true #In Test 
    #Set HP BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

if ($Manufacturer -match "Lenovo") {
    #Set Lenovo BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-LenovoBiosSettings.ps1)
    try {
        Manage-LenovoBIOSSettings -SetSettings
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
    
}


#write variables to console
Write-SectionHeader "OSDCloud Variables"
Write-Output $Global:MyOSDCloud

#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
import-module "$ModulePath\OSD.psd1" -Force

#Launch OSDCloud
Write-SectionHeader -Message "Starting OSDCloud"
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

Write-SectionHeader -Message "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot"



#Used in Testing "Beta Gary Modules which I've updated on the USB Stick"
$OfflineModulePath = (Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
write-host -ForegroundColor Yellow "Updating $OfflineModulePath using $ModulePath - For Dev Purposes Only"
copy-item "$ModulePath\*" "$OfflineModulePath"  -Force -Recurse

#Copy CMTrace Local:
if (Test-path -path "x:\windows\system32\cmtrace.exe"){
    copy-item "x:\windows\system32\cmtrace.exe" -Destination "C:\Windows\System\cmtrace.exe" -verbose
}

if ($Manufacturer -match "Lenovo") {
    $PowerShellSavePath = 'C:\Program Files\WindowsPowerShell'
    Write-Host "Copy-PSModuleToFolder -Name LSUClient to $PowerShellSavePath\Modules"
    Copy-PSModuleToFolder -Name LSUClient -Destination "$PowerShellSavePath\Modules"
}
#Restart
#restart-computer
