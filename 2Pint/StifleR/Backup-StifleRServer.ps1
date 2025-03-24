<#
Backup Before Upgrade

This is current setup using default paths, you may need to adjust for your environment
Eventually I'll try to make it smarter to detect where you installed the software and adjust accordingly

Basially, I run this script in my lab before I upgrade StifleR Server, it stops the services, backs up the files and database, then restarts the services.  I then take a snap shot of the VM before I upgrade the software.
#>

#Do you want to restart the service, or leave it off to do the update?
$RestartServicesAfterBackup = $false
#Confirm Paths for your environment!!!!
$BackupRootFolder = 'C:\Program Files\2Pint Software\StifleR Backups'
$StifleRServerRootPath = "C:\Program Files\2Pint Software\StifleR"
$StifleRDashBoardRootPath = "C:\Program Files\2Pint Software\StifleR Dashboards"
$StfileRDatabasePath  = "C:\ProgramData\2Pint Software\StifleR\Server"



function Get-InstalledApps
{
    if (![Environment]::Is64BitProcess) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

$StifleRServerAppInfo = Get-InstalledApps | Where-Object {$_.DisplayName -match "StifleR Server"}
$StifleRDashBoardAppInfo = Get-InstalledApps | Where-Object {$_.DisplayName -match "StifleR Dashboards"}



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
#Current Versions
Write-Host "Current StifleR Server Version: $($StifleRServerAppInfo.DisplayVersion), Installed on $($StifleRServerAppInfo.InstallDate)" -ForegroundColor Cyan
Write-Host "Current StifleR Dashboard Version: $($StifleRDashBoardAppInfo.DisplayVersion), Installed on $($StifleRDashBoardAppInfo.InstallDate)" -ForegroundColor Cyan
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor Yellow "Stopping StifleR Server Service(s)"
Get-Service -Name StifleRServer | Stop-Service
if ($Service = Get-Service -DisplayName '2Pint Software CacheR WebApi' -ErrorAction SilentlyContinue){$Service | Stop-Service}

Write-Host -ForegroundColor Yellow "Backing up StifleR Server Files | $StifleRServerRootPath"
Copy-Item $StifleRServerRootPath -Destination $CurrentBackupFolderPath -Recurse -Force
$StifleRServerAppInfo | Out-File -FilePath "$CurrentBackupFolderPath\StifleRServerAppInfo.txt"

write-Host -ForegroundColor Yellow "Backing up StifleR Dashboard Files | $StifleRDashBoardRootPath"
Copy-Item $StifleRDashBoardRootPath -Destination $CurrentBackupFolderPath -Recurse -Force
$StifleRDashBoardAppInfo | Out-File -FilePath "$CurrentBackupFolderPath\StifleRDashBoardAppInfo.txt"

write-Host -ForegroundColor Yellow "Backing up StifleR Database Files | $StfileRDatabasePath"
Copy-Item $StfileRDatabasePath -Destination $CurrentBackupFolderPath -Recurse -Force

if ($RestartServicesAfterBackup -eq $true){
    Write-Host -ForegroundColor Yellow "Starting StifleR Server Service(s)"
    Get-Service -Name StifleRServer | Start-Service
    if ($Service = Get-Service -DisplayName '2Pint Software CacheR WebApi' -ErrorAction SilentlyContinue){$Service | Start-Service}
}
else {
    Write-Host -ForegroundColor red "!!StifleR Server Service(s) are stopped, now is a good time to start your upgrade!!!"
}
Write-Host -ForegroundColor DarkGray "========================================================================="