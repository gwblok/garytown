

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
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
        
$AppCurrentInstall = Get-InstalledApps | Where-Object {$_.DisplayName -eq "git"}
[version]$AppCurrentInstallVersion = $AppCurrentInstall.DisplayVersion
if ($null -eq $AppCurrentInstallVersion){
    [version]$AppCurrentInstallVersion = '0.0.0.1'
}

# Ensure TLS 1.2 is used for the web request (required for GitHub API)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# GitHub API URL for the latest Git for Windows release
$apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

# Fetch the latest release data
$release = Invoke-RestMethod -Uri $apiUrl -Method Get

# Extract the version (tag_name) and other useful info
$version = $release.tag_name
[version]$NewRelease = ($version.Replace("v","").split(".") | Select-Object -First 3) -join "."
$publishedDate = $release.published_at
$downloadUrl = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).browser_download_url
$packageName = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).name



$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if($NewRelease.Build -eq -1){0}else{$NewRelease.Build}), $(if($NewRelease.Revision -eq -1){0}else{$NewRelease.Revision}))
if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion){
    Write-Output "Git already current: $NewRelease"
    exit 0
}
else{
    Write-Output "Git not current! Installed: $AppCurrentInstallVersion | Available: $NewRelease"
    exit 1
}
