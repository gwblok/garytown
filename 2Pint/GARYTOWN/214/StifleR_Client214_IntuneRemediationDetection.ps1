$TargetVersion = '2.14.2520.31'

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

$StifleRClientAppInfo = Get-InstalledApps | Where-Object {$_.DisplayName -match "StifleR Client"}

if ($null -eq $StifleRClientAppInfo){
    Write-Host "StifleR Client not installed - Trigger Remediation" -ForegroundColor Red
    exit 1
}
if ($StifleRClientAppInfo.DisplayVersion -ge $TargetVersion){
    Write-Host "StifleR Client version $($StifleRClientAppInfo.DisplayVersion) is the target version $TargetVersion - No remediation required" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "StifleR Client version $($StifleRClientAppInfo.DisplayVersion) is not the target version $TargetVersion - Trigger Remediation" -ForegroundColor Red
    exit 1
}