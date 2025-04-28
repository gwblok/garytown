

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
$apiUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"

# Fetch the latest release data
$release = Invoke-RestMethod -Uri $apiUrl -Method Get

# Extract the version (tag_name) and other useful info
$version = $release.tag_name
[version]$NewRelease = ($version.Replace("v","").split(".") | Select-Object -First 3) -join "."
$publishedDate = $release.published_at
$downloadUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
$packageName = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).name


# Define the base URL for the stable x64 system installer
$baseUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"

try {
    # Send a request and capture the redirect location without following it fully
    $response = Invoke-WebRequest -Uri $baseUrl -MaximumRedirection 0 -ErrorAction Stop 
    $redirectUrl = $response.Headers.Location

    # Extract the version number from the redirect URL (e.g., "1.87.2" from "/1.87.2/win32-x64/stable")
    if ($redirectUrl -match "/(\d+\.\d+\.\d+)/") {
        $version = $matches[1]
        Write-Host "Latest stable VS Code version: $version"
    } else {
        Write-Host "Could not parse version from URL: $redirectUrl"
    }
} catch {
    Write-Host "Error fetching the latest version: $_"
}
# Output the results
Write-Host "Latest Git for Windows Release:"
Write-Host "Version: $version"
Write-Host "Published Date: $publishedDate"
Write-Host "Download URL (64-bit): $downloadUrl"


$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if($NewRelease.Build -eq -1){0}else{$NewRelease.Build}), $(if($NewRelease.Revision -eq -1){0}else{$NewRelease.Revision}))
if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion){
    Write-Output "Git already current: $NewRelease"
}
else{
    Write-Verbose "About to download package from '$downloadURL'" -Verbose
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq "Desktop") {
        # On Windows PowerShell, progress can make the download significantly slower
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }

    try {
        #Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath
        Start-BitsTransfer -Source $downloadURL -Destination $packagePath
    } finally {
        if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq "Desktop") {
            $ProgressPreference = $oldProgressPreference
        }
    }
    if (Test-Path -Path $packagePath){
        $process = Start-Process $packagePath -ArgumentList /VERYSILENT -Wait -PassThru
    }
}
