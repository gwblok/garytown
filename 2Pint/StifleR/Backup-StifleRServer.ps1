<#
Backup Before Upgrade

This is current setup using default paths, you may need to adjust for your environment
Eventually I'll try to make it smarter to detect where you installed the software and adjust accordingly

Basically, I run this script in my lab before I upgrade StifleR Server, it stops the services, backs up the files and database, then restarts the services.  I then take a snap shot of the VM before I upgrade the software.
#>

#Do you want to restart the service, or leave it off to do the update?
$RestartServicesAfterBackup = $false
#Confirm Paths for your environment!!!!
$BackupRootFolder = 'C:\Program Files\2Pint Software\StifleR Backups'
$StifleRServerRootPath = "C:\Program Files\2Pint Software\StifleR"
$StifleRDashBoardRootPath = "C:\Program Files\2Pint Software\StifleR Dashboards"
$StifleRDatabasePath  = "C:\ProgramData\2Pint Software\StifleR\Server"
$StifleRUpdatePath = "D:\StifleRInstaller\Latest" #Path to where you downloaded the StifleR Server Installer


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

write-Host -ForegroundColor Yellow "Backing up StifleR Database Files | $StifleRDatabasePath"
Copy-Item $StifleRDatabasePath -Destination $CurrentBackupFolderPath -Recurse -Force

if ($RestartServicesAfterBackup -eq $true){
    Write-Host -ForegroundColor Yellow "Starting StifleR Server Service(s)"
    Get-Service -Name StifleRServer | Start-Service
    if ($Service = Get-Service -DisplayName '2Pint Software CacheR WebApi' -ErrorAction SilentlyContinue){$Service | Start-Service}
}
else {
    Write-Host -ForegroundColor red "!!StifleR Server Service(s) are stopped, now is a good time to start your upgrade!!!"
}
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

write-host "Press any key to continue - this will start the installer"
read-host

#Trigger Installers
if (Test-Path -Path $StifleRUpdatePath){
    Get-ChildItem -Path $StifleRUpdatePath -Recurse | Unblock-File
    $Zips = Get-ChildItem -Path $StifleRUpdatePath -Filter *.zip | Where-Object {$_.Name -match "StifleR" -and $_.Name -notmatch "Client"}
    foreach ($Zip in $Zips){
        
        [Version]$InstallerVersion = $zip.BaseName.split('_')[-1]
        if ($Zip.BaseName -match "StifleR.Installer"){
            [version]$InstalledVersion = $StifleRServerAppInfo.DisplayVersion
        }
        elseif ($Zip.BaseName -match "StifleR.Dashboard"){ 
            [version]$InstalledVersion = $StifleRDashBoardAppInfo.DisplayVersion

        }
        if($InstallerVersion -le $InstalledVersion){
            Write-Host "Installer Version: $InstallerVersion is less than or equal to Installed Version: $InstalledVersion, skipping installer" -ForegroundColor Red
        }
        else {
            Write-Host "Installer Version: $InstallerVersion is greater than Installed Version: $InstalledVersion, Extracting & Running Installer" -ForegroundColor Green
            $ExtractPath = "$($zip.Directory)\$($Zip.BaseName)"
            Expand-Archive -Path $Zip.fullname -DestinationPath $ExtractPath -Force
            $Installer = Get-ChildItem -Path $ExtractPath -Filter *.msi
            if ($Installer){
                Write-Host "Running Installer: $($Installer.FullName)"
                Start-Process -FilePath msiexec.exe -ArgumentList "/i $($Installer.FullName) " -Wait
                Write-Host "Finished Installer: $($Installer.FullName)"
            }
            else {
                Write-Host "No MSI found in $ExtractPath" -ForegroundColor Red
            }
        }

    }
}
else{
    Write-Host "No Installer Folder found" -ForegroundColor Red
}