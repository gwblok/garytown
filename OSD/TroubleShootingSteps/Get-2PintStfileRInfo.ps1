#Get 2Pint OSDToolkit Software Information

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp",
    [Parameter(Mandatory = $false)]
    [String]$logFile = "StifleRInfo.log"
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
    $StifleRClientService = Get-Service -Name StifleRClient | select-Object *
    $StifleRBinaryPath = $StifleRClientService.BinaryPathName
    if ($null -eq $StifleRBinaryPath){
        $StifleRInstallPath = "$env:ProgramFiles\2Pint Software\StifleR Client"
    }
    else{
        $StifleRInstallPath = $StifleRBinaryPath | Split-Path -Parent
    }
    if ($env:SystemDrive -eq "C:") {
        $StifleRClientAppInfo | Out-File -FilePath "$logPath\Gather-FullOS-$logFile" -Append -Force
        $StifleRClientService | Out-File -FilePath "$logPath\Gather-FullOS-$logFile" -Append -Force
        Copy-Item -Path "$StifleRInstallPath\StifleR.ClientApp.exe.Config" -Destination "$logPath\Gather-FullOS-StifleR.ClientApp.exe.Config" -Force
    }
    else {
        $StifleRClientAppInfo | Out-File -FilePath "$logPath\BootMedia-$logFile" -Append -Force
        $StifleRClientService | Out-File -FilePath "$logPath\BootMedia-$logFile" -Append -Force
        Copy-Item -Path "$StifleRInstallPath\StifleR.ClientApp.exe.Config" -Destination "$logPath\Gather-BootMedia-StifleR.ClientApp.exe.Config" -Force
    }
}