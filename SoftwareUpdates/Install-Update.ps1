<#
.SYNOPSIS
    Installs Windows updates from CAB or MSU files using DISM.

.DESCRIPTION
    This function installs Windows updates from CAB or MSU package files.
    It supports both online installation (running Windows) and offline installation (WinPE/OSDCloud).
    For MSU files, it will extract and install the contained CAB file.

.PARAMETER UpdatePath
    The full path to the update file (CAB or MSU).

.EXAMPLE
    Install-Update -UpdatePath "C:\Temp\Windows11.0-kb5027397-x64.cab"

.EXAMPLE
    Install-Update -UpdatePath "C:\Temp\windows11.0-kb5054156-x64.msu"

.NOTES
    Returns DISM exit code. 0 = Success, 3010 = Success with reboot required.
#>
Function Install-Update {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$UpdatePath
    )

    $scratchdir = 'C:\OSDCloud\Temp'
    if (!(Test-Path -Path $scratchdir)){
        New-Item -Path $scratchdir -ItemType Directory -Force | Out-Null
    }

    # Check if file is MSU and extract CAB if needed
    $fileExtension = [System.IO.Path]::GetExtension($UpdatePath).ToLower()
    $workingUpdatePath = $UpdatePath

    if ($fileExtension -eq ".msu") {
        Write-Output "MSU file detected. Extracting CAB from MSU..."
        
        # Create extraction directory
        $extractDir = Join-Path $env:TEMP "MSU_Extract_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $extractDir -ItemType Directory -Force | Out-Null
        
        # Extract MSU using expand.exe
        $expandArgs = "-F:* `"$UpdatePath`" `"$extractDir`""
        Write-Output "Extracting: expand.exe $expandArgs"
        $expandProcess = Start-Process "expand.exe" -ArgumentList $expandArgs -Wait -PassThru -NoNewWindow
        
        if ($expandProcess.ExitCode -ne 0) {
            Write-Error "Failed to extract MSU file. Exit code: $($expandProcess.ExitCode)"
            return $expandProcess.ExitCode
        }
        
        # Find the CAB file in the extracted contents
        $cabFile = Get-ChildItem -Path $extractDir -Filter "*.cab" | Where-Object { $_.Name -like "*Windows*" } | Select-Object -First 1
        
        if ($null -eq $cabFile) {
            Write-Error "No CAB file found in MSU package"
            return 1
        }
        
        $workingUpdatePath = $cabFile.FullName
        Write-Output "Found CAB file: $($cabFile.Name)"
    }

    # Determine if running in WinPE or full OS
    if ($env:SystemDrive -eq "X:"){
        $Process = "X:\Windows\system32\Dism.exe"
        $DISMArg = "/Image:C:\ /Add-Package /PackagePath:`"$workingUpdatePath`" /ScratchDir:`"$scratchdir`" /Quiet /NoRestart"
    }
    else {
        $Process = "C:\Windows\system32\Dism.exe"
        $DISMArg = "/Online /Add-Package /PackagePath:`"$workingUpdatePath`" /ScratchDir:`"$scratchdir`" /Quiet /NoRestart"
    }

    Write-Output "Starting Process of $Process -ArgumentList $DISMArg -Wait"
    $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru -NoNewWindow
    
    # Clean up extraction directory if MSU was used
    if ($fileExtension -eq ".msu" -and (Test-Path $extractDir)) {
        Write-Output "Cleaning up extraction directory..."
        Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    if ($DISM.ExitCode -eq 0) {
        Write-Output "Update installed successfully. Exit code: $($DISM.ExitCode)"
    }
    elseif ($DISM.ExitCode -eq 3010) {
        Write-Output "Update installed successfully. Reboot required. Exit code: $($DISM.ExitCode)"
    }
    else {
        Write-Warning "Update installation completed with exit code: $($DISM.ExitCode)"
    }
    
    return $DISM.ExitCode
}

<#
.SYNOPSIS
    Installs Windows 11 enablement package to upgrade to 23H2 or 25H2.

.DESCRIPTION
    This function downloads and installs the Windows 11 enablement package for the specified version.
    It automatically downloads the correct update file and installs it using the Install-Update function.

.PARAMETER Version
    The Windows 11 version to upgrade to. Valid values are "23H2" or "25H2".

.EXAMPLE
    Install-EnablementUpgrade -Version "23H2"
    Upgrades Windows 11 to version 23H2.

.EXAMPLE
    Install-EnablementUpgrade -Version "25H2"
    Upgrades Windows 11 to version 25H2.

.NOTES
    Requires administrator privileges.
    Returns DISM exit code. 0 = Success, 3010 = Success with reboot required.
    A reboot is typically required after installation.
#>
Function Install-EnablementUpgrade {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("23H2", "25H2")]
        [string]$Version
    )

    # Define URLs for each version
    $enablementPackages = @{
        "23H2" = @{
            URL = "https://raw.githubusercontent.com/gwblok/garytown/master/SoftwareUpdates/Windows11.0-kb5027397-x64.cab"
            FileName = "Windows11.0-kb5027397-x64.cab"
            KB = "KB5027397"
        }
        "25H2" = @{
            URL = "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/fa84cc49-18b2-4c26-b389-90c96e6ae0d2/public/windows11.0-kb5054156-x64_a0c1638cbcf4cf33dbe9a5bef69db374b4786974.msu"
            FileName = "windows11.0-kb5054156-x64.msu"
            KB = "KB5054156"
        }
    }

    $package = $enablementPackages[$Version]
    $downloadPath = Join-Path $env:TEMP $package.FileName

    Write-Output "=========================================="
    Write-Output "Windows 11 $Version Enablement Upgrade"
    Write-Output "=========================================="
    Write-Output "KB Article: $($package.KB)"
    Write-Output "Download URL: $($package.URL)"
    Write-Output "Local Path: $downloadPath"
    Write-Output ""

    # Download the update file
    Write-Output "Downloading Windows 11 $Version enablement package..."
    try {
        $ProgressPreference = 'SilentlyContinue'  # Speed up download
        Invoke-WebRequest -UseBasicParsing -Uri $package.URL -OutFile $downloadPath -ErrorAction Stop
        $ProgressPreference = 'Continue'
        Write-Output "Download completed successfully."
    }
    catch {
        Write-Error "Failed to download update package: $_"
        return 1
    }

    # Verify download
    if (!(Test-Path -Path $downloadPath)) {
        Write-Error "Downloaded file not found at: $downloadPath"
        return 1
    }

    $fileSize = (Get-Item $downloadPath).Length / 1MB
    Write-Output "Downloaded file size: $([math]::Round($fileSize, 2)) MB"
    Write-Output ""

    # Install the update
    Write-Output "Installing Windows 11 $Version enablement package..."
    Write-Output "This may take several minutes. Please wait..."
    Write-Output ""
    
    $exitCode = Install-Update -UpdatePath $downloadPath

    # Provide feedback based on exit code
    Write-Output ""
    Write-Output "=========================================="
    if ($exitCode -eq 0) {
        Write-Output "SUCCESS: Windows 11 $Version enablement package installed."
        Write-Output "A reboot is recommended to complete the upgrade."
    }
    elseif ($exitCode -eq 3010) {
        Write-Output "SUCCESS: Windows 11 $Version enablement package installed."
        Write-Output "A reboot is REQUIRED to complete the upgrade."
    }
    else {
        Write-Warning "Installation completed with exit code: $exitCode"
        Write-Output "Please check the DISM logs for more information."
    }
    Write-Output "=========================================="

    # Optional cleanup
    if (Test-Path $downloadPath) {
        Write-Output ""
        Write-Output "Cleaning up downloaded file..."
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    }

    return $exitCode
}

# Example usage (commented out - uncomment to run):
# Install-EnablementUpgrade -Version "23H2"
# Install-EnablementUpgrade -Version "25H2"
