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

Write-Host "Complete OSDCloud" -ForegroundColor Green
iex (irm hope.garytown.com)

#Setup Complete
Set-SetupCompleteCreateStart
Set-SetupCompleteOEMActivation
Set-SetupCompleteDefenderUpdate
Set-SetupCompleteStartWindowsUpdate
Set-SetupCompleteStartWindowsUpdateDriver
Set-SetupCompleteTimeZone
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish
