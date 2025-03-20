#https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1


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

$AppCurrentInstall = Get-InstalledApps | Where-Object {$_.DisplayName -match "PowerShell 7-"}
[version]$AppCurrentInstallVersion = $AppCurrentInstall.DisplayVersion
if ($null -eq $AppCurrentInstallVersion){
    [version]$AppCurrentInstallVersion = '0.0.0.1'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
        
$metadata = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json
$release = $metadata.ReleaseTag -replace '^v'
[Version]$NewRelease = $release
$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if($NewRelease.Build -eq -1){0}else{$NewRelease.Build}), $(if($NewRelease.Revision -eq -1){0}else{$NewRelease.Revision}))
if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion){
    Write-Output "PowerShell already current: $NewRelease"
    exit 0
}
else {
    Write-Output "PowerShell not current! Installed: $AppCurrentInstallVersion | Available: $NewRelease"
    exit 1
}
