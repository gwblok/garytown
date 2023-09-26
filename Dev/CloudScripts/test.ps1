$ScriptName = 'test.garytown.com'
$ScriptVersion = '23.9.26.1'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"

iex (irm functions.garytown.com)

if (Test-DISMFromOSDCloudUSB -eq $false){
    $Global:MyOSDCloud = [ordered]@{
            Restart = [bool]$False
            RecoveryPartition = [bool]$True
            SkipAllDiskSteps = [bool]$False
            DriverPackName = "None"
    }
}
else {
    $Global:MyOSDCloud = [ordered]@{
            Restart = [bool]$False
            RecoveryPartition = [bool]$True
            SkipAllDiskSteps = [bool]$False
    }
}
#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
import-module "$ModulePath/OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
Start-OSDCloud -OSName 'Windows 11 22H2 x64' -OSEdition Pro -OSActivation Retail -ZTI -OSLanguage en-us

#Write-Host "Complete OSDCloud" -ForegroundColor Green
#iex (irm hope.garytown.com)

#Setup Complete
Write-Host "Creating SetupComplete Process" -ForegroundColor Green
Set-SetupCompleteCreateStart
Write-Host "  Enable OEM Activation" -ForegroundColor gray
Set-SetupCompleteOEMActivation
Write-Host "  Enable Defender Updates" -ForegroundColor gray
Set-SetupCompleteDefenderUpdate
Write-Host "  Enable Windows Updates" -ForegroundColor gray
Set-SetupCompleteStartWindowsUpdate
Write-Host "  Enable MS Driver Updates" -ForegroundColor gray
Set-SetupCompleteStartWindowsUpdateDriver
Write-Host "  Set Time Zone Updates" -ForegroundColor gray
Set-SetupCompleteTimeZone
Write-Host "  Check for Setup Complete on CloudUSB Drive" -ForegroundColor gray
Set-SetupCompleteOSDCloudUSB
Write-Host "Conclude SetupComplete Process Creation" -ForegroundColor Green
Set-SetupCompleteCreateFinish
