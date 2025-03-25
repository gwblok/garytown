<#
Backup Before Upgrade

This is current setup using default paths, you may need to adjust for your environment
Eventually I'll try to make it smarter to detect where you installed the software and adjust accordingly

Basially, I run this script in my lab before I upgrade StifleR Server, it stops the services, backs up the files and database, then restarts the services.  I then take a snap shot of the VM before I upgrade the software.
#>
$BackupRootFolder = 'C:\Program Files\2Pint Software\StifleR Backups'

$StifleRServerRootPath = "C:\Program Files\2Pint Software\StifleR"
$StifleRDashBoardRootPath = "C:\Program Files\2Pint Software\StifleR Dashboards"
$StfileRDatabasePath  = "C:\ProgramData\2Pint Software\StifleR\Server"

$Date = Get-Date -Format yyyyMMdd
$CurrentBackupFolderPath = "$BackupRootFolder\$Date"
if (Test-Path -Path $CurrentBackupFolderPath){
    Write-Host "Already Backed up today.  IF you want to do it again, delete folder first"
}
else{
    New-Item -Path $CurrentBackupFolderPath -ItemType Directory -Force |Out-Null
}

Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Starting Backup of StifleR Server"
write-host -ForegroundColor DarkGray " StifleR Server Backup Path: $CurrentBackupFolderPath"
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "Stopping StifleR Server Service(s)"
Get-Service -Name StifleRServer | Stop-Service
if ($Service = Get-Service -DisplayName '2Pint Software CacheR WebApi' -ErrorAction SilentlyContinue){$Service | Stop-Service}
Write-Host -ForegroundColor Yellow "Backing up StifleR Server Files | $StifleRServerRootPath"
Copy-Item $StifleRServerRootPath -Destination $CurrentBackupFolderPath -Recurse -Force
write-Host -ForegroundColor Yellow "Backing up StifleR Dashboard Files | $StifleRDashBoardRootPath"
Copy-Item $StifleRDashBoardRootPath -Destination $CurrentBackupFolderPath -Recurse -Force
write-Host -ForegroundColor Yellow "Backing up StifleR Database Files | $StfileRDatabasePath"
Copy-Item $StfileRDatabasePath -Destination $CurrentBackupFolderPath -Recurse -Force
Write-Host -ForegroundColor Yellow "Starting StifleR Server Service(s)"
Get-Service -Name StifleRServer | Start-Service
if ($Service = Get-Service -DisplayName '2Pint Software CacheR WebApi' -ErrorAction SilentlyContinue){$Service | Start-Service}
Write-Host -ForegroundColor DarkGray "========================================================================="

Write-Host -ForegroundColor Magenta "Getting Data used for Upgrade"
[XML]$StifleROverride = Get-Content -Path "$CurrentBackupFolderPath\StifleR\appSettings-override.xml"
$Data = $StifleROverride.appSettings.add
$SignalRCertificateThumbprint = $Data | Where-Object { $_.key -eq 'SignalRCertificateThumbprint' } | Select-Object -ExpandProperty value
Write-Host "SignalRCertificateThumbprint: $SignalRCertificateThumbprint"
$LicenseKey = $Data | Where-Object { $_.key -eq 'LicenseKey' } | Select-Object -ExpandProperty value
Write-Host "LicenseKey: $LicenseKey"

$DashBoardConfig = Get-Content -Path "$CurrentBackupFolderPath\StifleR Dashboards\Dashboard Files\assets\config\config.json" | ConvertFrom-Json
$DashBoardConfig.apiServers