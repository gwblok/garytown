#Get 2Pint OSDToolkit Software Information

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp"
)
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

$StifleRClientAppInfo = Get-InstalledApps | Where-Object {$_.DisplayName -match "StifleR"}


if ($StifleRClientAppInfo) {
    $StifleRClientService = Get-Service -Name StifleRClient | select-Object -Property Name, DisplayName, Status, BinaryPathName
    $StifleRBinaryPath = $StifleRClientService.BinaryPathName
    $StifleRInstallPath = $StifleRBinaryPath | Split-Path -Parent
    if ($env:SystemDrive -eq "C:") {
        $StifleRClientAppInfo | Out-File -FilePath "$logPath\FULLOS-StifleRClientServiceInfo.log" -Append -Force
        $StifleRClientService | Out-File -FilePath "$logPath\FULLOS-StifleRClientServiceInfo.log" -Append -Force
        Copy-Item -Path "$StifleRInstallPath\StifleR.ClientApp.exe.Config" -Destination "$logPath\FULLOS-StifleR.ClientApp.exe.Config" -Force
    }
    else {
        $StifleRClientAppInfo | Out-File -FilePath "$logPath\BootMedia-StifleRClientServiceInfo.log" -Append -Force
        $StifleRClientService | Out-File -FilePath "$logPath\BootMedia-StifleRClientServiceInfo.log" -Append -Force
        Copy-Item -Path "$StifleRInstallPath\StifleR.ClientApp.exe.Config" -Destination "$logPath\BootMedia-StifleR.ClientApp.exe.Config" -Force
    }
}

