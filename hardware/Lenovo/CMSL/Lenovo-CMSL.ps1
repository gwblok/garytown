<#
.SYNOPSIS
    Script to manage Lenovo Client Management Script Library (CMSL) and Lenovo System Updater.

.DESCRIPTION
    
    This script contains functions to download and import the Lenovo CMSL, install the Lenovo System Updater, 
    and invoke the Lenovo System Updater if it is not already installed. The script ensures that the latest 
    version of the Lenovo System Updater is downloaded and installed silently.

.FUNCTIONS
    Import-ModuleLenovoCMSL
        Downloads and imports the Lenovo Client Management Script Library (CMSL).

    Install-LenovoSystemUpdater
        Downloads and installs the Lenovo System Updater using the Lenovo CMSL module.

    Invoke-LenovoSystemUpdater
        Checks if the Lenovo System Updater is installed, and if not, installs it.

    Install-LenovoVantage
        Downloads and installs Lenovo Vantage silently.
        NOTE: Requires you to keep the download URL Updated - https://support.lenovo.com/us/en/solutions/hf003321-lenovo-vantage-for-enterprise

    
        Set-LenovoVantage
        Sets the registry values for Lenovo Vantage.

.NOTES
    Author: Gary Blok
    Date: 25.01.27
    Version: 25.01.27

.EXAMPLE
    Import-ModuleLenovoCMSL
    Install-LenovoSystemUpdater
    Invoke-LenovoSystemUpdater
    Install-LenovoVantage
    Set-LenovoVantage
    Set-LenovoVantageSU
    Set-LenovoVantageAutoUpdates
    Reset-LenovoVantageSettings

.LINK
    Lenovo Client Scripting Module (CMSL) Documentation:
    https://docs.lenovocdrt.com/guides/lcsm/lcsm_top/#installing-lenovo-client-scripting-module

#>

$ScriptVersion = "25.01.27"
Write-Output "Loading Lenovo Tools Script Version $ScriptVersion"

Function Import-ModuleLenovoCMSL {
    #Function to download Lenovo CMSL to programdata\CMSL then import
    [CmdletBinding()]
    param ()
    
    try {
        import-module -name Lenovo.Client.Scripting -ErrorAction SilentlyContinue
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
    if (get-module -name Lenovo.Client.Scripting -ListAvailable) {
        Write-Verbose "Lenovo CMSL Module is already installed."
        return
    }
    $URL = "https://download.lenovo.com/cdrt/tools/Lenovo.Client.Scripting_2.1.0.zip"
    $FileName = $URL.Split("/")[-1]
    #$FolderName = $FileName.Replace(".zip","")
    $Destination = "$env:programdata\CMSL\$FileName"
    $ExtractedFolder = "C:\Program Files\WindowsPowerShell\Modules"


    if (!(Test-Path -Path $ExtractedFolder)){
        New-Item -Path $ExtractedFolder -ItemType Directory | Out-Null
    }
    if (!(Test-Path -Path $Destination)){
        Start-BitsTransfer -Source $URL -Destination $Destination -DisplayName "Lenovo CMSL Download"
    }
    Expand-Archive -Path $Destination -DestinationPath $ExtractedFolder -Force
    $LenovoModule = Get-ChildItem -Path $ExtractedFolder -Recurse | Where-Object { $_.Name -eq "Lenovo.Client.Scripting.psm1" } 
    Import-Module -Name $LenovoModule.FullName -Force
}

function Install-LenovoSystemUpdater {
    # Define the URL and temporary file path
    Import-ModuleLenovoCMSL
    $URL = Find-LnvTool -Tool SystemUpdate -Url
    #$url = "https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.08.02.25.exe" #No longer needed, uses the Lenovo CMSL Module to get latest version
    $tempFilePath = "C:\Windows\Temp\system_update.exe"

    # Create a new BITS transfer job
    $bitsJob = Start-BitsTransfer -Source $url -Destination $tempFilePath -DisplayName "Lenovo System Updater Download"

    # Wait for the BITS transfer job to complete
    while ($bitsJob.JobState -eq "Transferring") {
        Start-Sleep -Seconds 2
    }

    # Check if the transfer was successful
    if (Test-Path -Path $tempFilePath) {
        # Start the installation process
        Write-Host -ForegroundColor Green "Installation file downloaded successfully. Starting installation..."
        $ArgumentList = "/VERYSILENT /NORESTART"
        $InstallProcess = Start-Process -FilePath $tempFilePath -ArgumentList $ArgumentList -Wait -PassThru
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Host -ForegroundColor Green "Installation completed successfully."
        } else {
            Write-Host -ForegroundColor Red "Installation failed with exit code $($InstallProcess.ExitCode)."
        }
    } else {
        Write-Host "Failed to download the file."
    }
}

#This is basic pre-programmed right now, will eventually build out to add parameters
function Invoke-LenovoSystemUpdater
{
    # Check if Lenovo System Updater is already installed
    if (Test-Path "C:\Program Files (x86)\Lenovo\System Update\TVSU.exe") {
        Write-Host "Lenovo System Updater is already installed."
    } else {
        Write-Host "Lenovo System Updater is not installed. Installing..."
        Install-LenovoSystemUpdater
    }
    $ArgList = '/CM -search A -action INSTALL -includerebootpackages 3 -nolicense -exporttowmi -noreboot -noicon'
    $Updater = Start-Process -FilePath "C:\Program Files (x86)\Lenovo\System Update\TVSU.exe" -ArgumentList $ArgList  -Wait -PassThru

    if ($Updater.ExitCode -eq 0) {
        Write-Host -ForegroundColor Green "Lenovo System Updater completed successfully."
    } else {
        Write-Host -ForegroundColor Red "Lenovo System Updater failed with exit code $($Updater.ExitCode)."
    }
}

function Install-LenovoVantage {
    # Define the URL and temporary file path - https://support.lenovo.com/us/en/solutions/hf003321-lenovo-vantage-for-enterprise
    #$url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2401.29.0.zip"
    $url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2501.15.0_v3.zip"
    $tempFilePath = "C:\Windows\Temp\lenovo_vantage.zip"
    $tempExtractPath = "C:\Windows\Temp\LenovoVantage"
    # Create a new BITS transfer job
    $bitsJob = Start-BitsTransfer -Source $url -Destination $tempFilePath -DisplayName "Downloading to $tempFilePath"

    # Wait for the BITS transfer job to complete
    while ($bitsJob.JobState -eq "Transferring") {
        Start-Sleep -Seconds 2
    }

    # Check if the transfer was successful
    if (Test-Path -Path $tempFilePath) {
        # Start the installation process
        Write-Host -ForegroundColor Green "Installation file downloaded successfully. Starting installation..."
        Write-Host -ForegroundColor Cyan " Extracting $tempFilePath to $tempExtractPath"
        if (test-path -path $tempExtractPath) {Remove-Item -Path $tempExtractPath -Recurse -Force}
        Expand-Archive -Path $tempFilePath -Destination $tempExtractPath

    } else {
        Write-Host "Failed to download the file."
    }
    #Lenovo System Interface Foundation (LSIF)
    if (Test-Path -Path "$tempExtractPath\System-Interface-Foundation-Update-64.exe"){
        Write-Host -ForegroundColor Cyan " Installing Lenovo System Interface Foundation..."
        $ArgumentList = "/VERYSILENT /NORESTART"
        $InstallProcess = Start-Process -FilePath "$tempExtractPath\System-Interface-Foundation-Update-64.exe" -ArgumentList $ArgumentList -Wait -PassThru
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Host -ForegroundColor Cyan "  Installation completed successfully."
        } else {
            Write-Host -ForegroundColor Red "  Installation failed with exit code $($InstallProcess.ExitCode)."
        }
    } else {
        Write-Host -ForegroundColor red " Failed to find $tempExtractPath\System-Interface-Foundation-Update-64.exe"
    }
    #Lenovo Vantage Service
    Write-Host -ForegroundColor Cyan " Installing Lenovo Vantage Service..."
    Invoke-Expression -command "$tempExtractPath\VantageService\Install-VantageService.ps1"

    #Lenovo Vantage Batch File
    write-host -ForegroundColor Cyan " Installing Lenovo Vantage...batch file..."
    $ArgumentList = "/c $($tempExtractPath)\setup-commercial-vantage.bat"
    $InstallProcess = Start-Process -FilePath "cmd.exe" -ArgumentList $ArgumentList -Wait -PassThru
    if ($InstallProcess.ExitCode -eq 0) {
        Write-Host -ForegroundColor Green "Lenovo Vantage completed successfully."
    } else {
        Write-Host -ForegroundColor Red "Lenovo Vantage failed with exit code $($InstallProcess.ExitCode)."
    }
}


function Set-LenovoVantage {
    [CmdletBinding()]
    param (
        [ValidateSet('True','False')]
        [string]$AcceptEULAAutomatically = 'True',
        [ValidateSet('True','False')]
        [string]$WarrantyInfoHide,
        [ValidateSet('True','False')]
        [string]$WarrantyWriteWMI,
        [ValidateSet('True','False')]
        [string]$MyDevicePageHide,
        [ValidateSet('True','False')]
        [string]$WiFiSecurityPageHide,
        [ValidateSet('True','False')]
        [string]$HardwareScanPageHide,
        [ValidateSet('True','False')]
        [string]$GiveFeedbackPageHide    
    )

    
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    # Check if Lenovo Vantage is installed
    if (Test-Path "C:\Program Files (x86)\Lenovo\VantageService") {
        #Write-Host "Lenovo Vantage is already installed."
    } else {
        Write-Host "Lenovo Vantage is not installed. Installing..."
        Install-LenovoVantage
    }
    # Check if the registry path exists
    if (Test-Path $RegistryPath) {
        #Write-Host "Registry path already exists"
    } else {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    
    # Set the registry values
    if ($AcceptEULAAutomatically) {
        if ($AcceptEULAAutomatically -eq $true){
            Write-Host "Setting AcceptEULAAutomatically to 1"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AcceptEULAAutomatically to 0"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($WarrantyInfoHide) {
        if ($WarrantyInfoHide -eq $true){
            Write-Host "Setting WarrantyInfoHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyInfoHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($WarrantyWriteWMI) {
        if ($WarrantyWriteWMI -eq $true){
            Write-Host "Setting WarrantyWriteWMI to 1"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyWriteWMI to 0"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($MyDevicePageHide) {
        if ($MyDevicePageHide -eq $true){
            Write-Host "Setting MyDevicePageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting MyDevicePageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($WiFiSecurityPageHide) {
        if ($WiFiSecurityPageHide -eq $true){
            Write-Host "Setting WiFiSecurityPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WiFiSecurityPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($HardwareScanPageHide) {
        if ($HardwareScanPageHide -eq $true){
            Write-Host "Setting HardwareScanPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting HardwareScanPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }

    if ($GiveFeedbackPageHide) {
        if ($GiveFeedbackPageHide -eq $true){
            Write-Host "Setting GiveFeedbackPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting GiveFeedbackPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
}


function Set-LenovoVantageSU {
    [CmdletBinding()]
    param (

        [string]$CompanyName,
        [string]$SystemUpdateRepository,
        [ValidateSet('True','False')]
        [string]$ConfigureSystemUpdate = $true,

        #ConfigureSystemUpdateUpdates
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalDriver,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedAll,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedDrivers,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalDrivers,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalOther
    )

    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    if ($CompanyName) {
        New-ItemProperty -Path $RegistryPath -Name "CompanyName" -Value $CompanyName -PropertyType string -Force | Out-Null
    }
    if ($SystemUpdateRepository) {
        New-ItemProperty -Path $RegistryPath -Name "LocalRepository" -Value $SystemUpdateRepository -PropertyType string -Force | Out-Null
    }
    if ($ConfigureSystemUpdate) {
        if ($ConfigureSystemUpdate -eq $true){
            Write-Host "Setting SystemUpdateFilter to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
#ConfigureSystemUpdateUpdates
    #Region Critical
    if ($SUFilterCriticalAll) {
        if ($SUFilterCriticalAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterCriticalApplication) {
        if ($SUFilterCriticalApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalDriver) {
        if ($SUFilterCriticalDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalBIOS) {
        if ($SUFilterCriticalBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalFirmware) {
        if ($SUFilterCriticalFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalOthers) {
        if ($SUFilterCriticalOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion Critical
    #Region Recommended
    if ($SUFilterRecommendedAll) {
        if ($SUFilterRecommendedAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterRecommendedApplication) {
        if ($SUFilterRecommendedApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedDriver) {
        if ($SUFilterRecommendedDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedBIOS) {
        if ($SUFilterRecommendedBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedFirmware) {
        if ($SUFilterRecommendedFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedOthers) {
        if ($SUFilterRecommendedOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion recommended
    #Region optional
    if ($SUFilterOptionalAll) {
        if ($SUFilterOptionalAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterOptionalApplication) {
        if ($SUFilterOptionalApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalDriver) {
        if ($SUFilterOptionalDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalBIOS) {
        if ($SUFilterOptionalBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalFirmware) {
        if ($SUFilterOptionalFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalOthers) {
        if ($SUFilterOptionalOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion optional
}

function Set-LenovoVantageAutoUpdates {
    [CmdletBinding()]
    param (

        [string]$CompanyName,
        [string]$SystemUpdateRepository,
        [ValidateSet('True','False')]
        [string]$AutoUpdateEnabled,
        [ValidateSet('True','False')]
        [string]$ConfigureAutoUpdate,
        [Parameter(HelpMessage="Format HH:mm:ss For example 18:30:00 for 6:30PM")]
        [ValidatePattern("[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")]
        [string]$ScheduleTimeAutoUpdate,

        
        #Update Deferrals
        [ValidateSet('Enabled','Disabled')]
        [string]$UpdateDeferrals,
        [Parameter(HelpMessage="number of times the end-user is allowed to defer updates (DeferLimit)")]
        [ValidateRange(0,100)]
        [string]$DeferLimit,
        [Parameter(HelpMessage="amount of time for each deferral (DeferTime)")]
        [ValidateRange(0,60)]
        [string]$DeferTime,


        #ConfigureSystemUpdateUpdates
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalDriver,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedAll,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedDrivers,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalDrivers,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalOther
    )

    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    #Enabling Dependencies
    if ($ScheduleTimeAutoUpdate){$AutoUpdateEnabled = $true}
    if ($DeferLimit) {$UpdateDeferrals = "Enabled"}
    if ($DeferTime)  {$UpdateDeferrals = "Enabled"}
    if ($UpdateDeferrals){$AutoUpdateEnabled = $true}
    if ($AutoUpdateEnabled) {$ConfigureAutoUpdate = $true}

    #Start Doing Stuff
    if ($CompanyName) {
        New-ItemProperty -Path $RegistryPath -Name "CompanyName" -Value $CompanyName -PropertyType string -Force | Out-Null
    }
    if ($SystemUpdateRepository) {
        New-ItemProperty -Path $RegistryPath -Name "LocalRepository" -Value $SystemUpdateRepository -PropertyType string -Force | Out-Null
    }
    if ($AutoUpdateEnabled) {
        if ($AutoUpdateEnabled -eq $true){
            Write-Host "Setting AutoUpdateEnabled to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoUpdateEnabled" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoUpdateEnabled to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoUpdateEnabled" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($ConfigureAutoUpdate) {
        if ($ConfigureAutoUpdate -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($ScheduleTimeAutoUpdate) {
        Write-Host "Setting AutoUpdateScheduleTime to $ScheduleTimeAutoUpdate"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateScheduleTime" -Value $ScheduleTimeAutoUpdate -PropertyType string -Force | Out-Null
    }
    
    #Deferrals

    if ($UpdateDeferrals) {
        if ($UpdateDeferrals -eq "Enabled"){
            Write-Host "Setting DeferUpdateEnabled to 1"
            New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled" -Value 1 -PropertyType dword -Force | Out-Null

            if ($DeferLimit) {
                Write-Host "Setting DeferUpdateEnabled.Limit to $DeferLimit"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Value $DeferLimit -PropertyType string -Force | Out-Null
            }
            else {
                Write-Host "Setting DeferUpdateEnabled.Limit to Default"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Value "" -PropertyType string -Force | Out-Null 
            }
            if ($DeferTime) {
                Write-Host "Setting DeferUpdateEnabled.Time to $DeferTime"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Value $DeferTime -PropertyType string -Force | Out-Null
            }
            else {
                Write-Host "Setting DeferUpdateEnabled.Time to Default of 60"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Value "60" -PropertyType string -Force | Out-Null
            }
        }
        elseif ($UpdateDeferrals -eq "Disabled") {
            Write-Host "Removing Update Deferral Properties"
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled" -Force | Out-Null
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Force | Out-Null
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Force | Out-Null

        }
    }

    
#ConfigureSystemUpdateUpdates
    #Region Critical
    if ($SUFilterCriticalAll) {
        if ($SUFilterCriticalAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterCriticalApplication) {
        if ($SUFilterCriticalApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalDriver) {
        if ($SUFilterCriticalDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalBIOS) {
        if ($SUFilterCriticalBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalFirmware) {
        if ($SUFilterCriticalFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalOthers) {
        if ($SUFilterCriticalOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion Critical
    #Region Recommended
    if ($SUFilterRecommendedAll) {
        if ($SUFilterRecommendedAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterRecommendedApplication) {
        if ($SUFilterRecommendedApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedDriver) {
        if ($SUFilterRecommendedDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedBIOS) {
        if ($SUFilterRecommendedBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedFirmware) {
        if ($SUFilterRecommendedFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedOthers) {
        if ($SUFilterRecommendedOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion recommended
    #Region optional
    if ($SUFilterOptionalAll) {
        if ($SUFilterOptionalAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterOptionalApplication) {
        if ($SUFilterOptionalApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalDriver) {
        if ($SUFilterOptionalDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalBIOS) {
        if ($SUFilterOptionalBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalFirmware) {
        if ($SUFilterOptionalFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalOthers) {
        if ($SUFilterOptionalOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion optional
}

function Reset-LenovoVantageSettings {
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    #Delete all the Properties under the Registry Key
    (Get-Item -Path $RegistryPath).Property | ForEach-Object {
        Remove-ItemProperty -Path $RegistryPath -Name $_ -Force -Verbose
    }
}

<# Still noodling on.
function Get-LenovoDeviceDetails {
    param (
        [ValidateLength(4,4)][parameter(position = 0, Mandatory = $false, helpMessage = "Enter the four-character Machine Type to search for", ParameterSetName="MT")] [String] $MachineType
    )
    
    Import-ModuleLenovoCMSL
    $Manufacturer = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
    if ($Manufacturer -eq "LENOVO") {
        $MachineType = Get-LnvMachineType
    }
    if (!($MachineType)){Write-Output "Machine Type not found.  Please provide one, or run on Lenovo Device"; return}

    #Pull in Private Functions from Lenovo CMSL
    $ModuleBase = (Get-Module Lenovo.Client.Scripting).ModuleBase
    Get-ChildItem -Path "$ModuleBase\Private" | ForEach-Object {Import-Module $_.FullName}
    if (-not[string]::IsNullOrWhiteSpace($MachineType)) {
        $searchString = $MachineType.ToUpper().Trim()
    } elseif (-not[string]::IsNullOrWhiteSpace($Bios)) {
        $searchString = $Bios.ToUpper().Trim()
    } else {
        return
    }

    try {
        [xml]$catalog = Get-LnvDATCatalog
    }
    catch {
        Write-Output $_
        return
    }
    $node = $catalog.ModelList.Model | Where-Object { ($_.Types.Type.Contains("$searchString")) -or ($_.BIOS.image.ToUpper() -eq $("$searchString")) }
    if($null -eq $node)
    {
        Write-Output "No models were found with $searchString"
        return
    }
    #Write-Output -InputObject ($node.name)
    $DeviceOutput = New-Object -TypeName PSObject
    $DeviceOutput | Add-Member -MemberType NoteProperty -Name "BIOS" -Value "$($node.BIOS.image)" -Force
    $DeviceOutput | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($node.name)"  -Force
    $DeviceOutput | Add-Member -MemberType NoteProperty -Name "RTSDate" -Value $([DATETIME]$RDSDate) -Force
    return $DeviceOutput

}

#>