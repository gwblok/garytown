

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

$AppCurrentInstall = Get-InstalledApps | Where-Object {$_.DisplayName -eq "git"}


# Ensure TLS 1.2 is used for the web request (required for GitHub API)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# GitHub API URL for the latest Git for Windows release
$apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

# Fetch the latest release data
$release = Invoke-RestMethod -Uri $apiUrl -Method Get

# Extract the version (tag_name) and other useful info
$version = $release.tag_name
$NewRelease = ($version.Replace("v","").split(".") | Select-Object -First 3) -join "."
$publishedDate = $release.published_at
$downloadUrl = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).browser_download_url
$packageName = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).name

# Output the results
Write-Host "Latest Git for Windows Release:"
Write-Host "Version: $version"
Write-Host "Published Date: $publishedDate"
Write-Host "Download URL (64-bit): $downloadUrl"


$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if($NewRelease.Build -eq -1){0}else{$NewRelease.Build}), $(if($NewRelease.Revision -eq -1){0}else{$NewRelease.Revision}))
if ([Version]$NewRelease -match [version]$AppCurrentInstall.DisplayVersion){
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
