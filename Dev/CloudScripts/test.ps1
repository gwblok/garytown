$ScriptName = 'test.garytown.com'
$ScriptVersion = '23.11.01.01'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"
iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

<# Offline Driver Details
If you extract Driver Packs to your Flash Drive, you can DISM them in while in WinPE and it will make the process much faster, plus ensure driver support for first Boot
Extract to: OSDCLoudUSB:\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct
Use OSD Module to determine Vars
$ComputerProduct = (Get-MyComputerProduct)
$ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
#>


if (Test-DISMFromOSDCloudUSB -eq $true){
    Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
    $Global:MyOSDCloud = [ordered]@{
            Restart = [bool]$False
            RecoveryPartition = [bool]$True
            SkipAllDiskSteps = [bool]$False
            DriverPackName = "None"
            OSDCloudUnattend = [bool]$True

    }
}
else {
    $Global:MyOSDCloud = [ordered]@{
            Restart = [bool]$False
            RecoveryPartition = [bool]$True
            SkipAllDiskSteps = [bool]$False

    }
}

#Enable HPIA | Update HP BIOS | Update HP TPM
if (Test-HPIASupport){
    $Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    $Global:MyOSDCloud.HPIAALL = [bool]$true
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true

}

#write variables to console
$Global:MyOSDCloud

#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
import-module "$ModulePath/OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
Start-OSDCloud -OSName 'Windows 11 22H2 x64' -OSEdition Pro -OSActivation Retail -ZTI -OSLanguage en-us



if (Test-DISMFromOSDCloudUSB){
    Start-DISMFromOSDCloudUSB
}

$OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
$UpdatesPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS\Updates"
$MSUUpdates = Get-ChildItem -Path $UpdatesPath -Recurse -Filter *.msu
$Windows11MSUUpdates = $MSUUpdates | Where-Object {$_.name -match "windows11"}
$Windows1122H2MSUUpdates = $Windows11MSUUpdates | Where-Object {$_.FullName -match "22H2"}

Write-Output "Current OS UBR: $(Get-UBR)"

foreach ($Update in $Windows1122H2MSUUpdates){
    $Update.FullName
}
Write-Host "Starting DISM Update Process"
foreach ($Update in $Windows1122H2MSUUpdates){
    Install-MSU -MSUPath $Update.FullName
}
Write-Output "Current OS UBR: $(Get-UBR)"


#Setup Complete (OSDCloud WinPE stage is complete)
Write-Host "Creating SetupComplete Process" -ForegroundColor Green
Set-SetupCompleteCreateStart
Write-Host "  Enable OEM Activation" -ForegroundColor gray
Set-SetupCompleteOEMActivation
Write-Host "  Enable Defender Updates" -ForegroundColor gray
Set-SetupCompleteDefenderUpdate
Write-Host "  Enable Windows Updates" -ForegroundColor gray
Set-SetupCompleteStartWindowsUpdate
#Write-Host "  Enable MS Driver Updates" -ForegroundColor gray
#Set-SetupCompleteStartWindowsUpdateDriver
Write-Host "  Set Time Zone Updates" -ForegroundColor gray
Set-SetupCompleteTimeZone
Write-Host "  Check for Setup Complete on CloudUSB Drive" -ForegroundColor gray
Set-SetupCompleteOSDCloudUSB
Write-Host "Conclude SetupComplete Process Creation" -ForegroundColor Green
Set-SetupCompleteCreateFinish
#>
