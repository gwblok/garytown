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
$architecture = "x64"
$originalValue = [Net.ServicePointManager]::SecurityProtocol
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
        
$metadata = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json
$release = $metadata.ReleaseTag -replace '^v'
[Version]$NewRelease = $release
$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if($NewRelease.Build -eq -1){0}else{$NewRelease.Build}), $(if($NewRelease.Revision -eq -1){0}else{$NewRelease.Revision}))
if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion){
    Write-Output "PowerShell already current: $NewRelease"
}
else {
    $packageName = "PowerShell-${release}-win-${architecture}.msi"
    $downloadURL = "https://github.com/PowerShell/PowerShell/releases/download/v${release}/${packageName}"
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
        $MSIArguments = @()
        $MSIArguments += "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1"
        $MSIArguments += "ENABLE_PSREMOTING=1"
        $ArgumentList=@("/i", $packagePath, "/quiet")
        $ArgumentList+=$MSIArguments
        $process = Start-Process msiexec -ArgumentList $ArgumentList -Wait -PassThru
    }
}
