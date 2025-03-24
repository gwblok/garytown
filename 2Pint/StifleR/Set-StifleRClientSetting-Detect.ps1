# Script to check the StifleR Client VPNString
# NOTE: Using sc.exe stop/start the service, and query service state, rather than PS or .NET (We found it more reliable)

# Variables
$ServiceName = "StifleRClient"
$LogPath = "C:\Windows\Temp\StifleRClientConfiguration_Discovery.log"
$Compliance = "Non-Compliant" # Assume non-compliant, if running script multiple times
$SettingName = 'StiflerServers'
$DesiredValue = "https://2PSR210.2p.garytown.com:1414"

# Delete any existing logfile if it exists
If (Test-Path $LogPath){Remove-Item $LogPath -Force -ErrorAction SilentlyContinue -Confirm:$false}

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
    )

    $TimeGenerated = $(Get-Date -UFormat "%D %T")
    $Line = "$TimeGenerated : $Message"
    Add-Content -Value $Line -Path $LogPath -Encoding Ascii
}

Function Get-AppSetting{
    param (
    [Parameter(Mandatory = $true)]
    [string]$PathToConfig
    )

    if (Test-Path $PathToConfig){
        $x =  [Xml] (type $PathToConfig)
        $x.configuration.appSettings.add
    }
    else{
        Write-Log "Configuration File $PathToConfig Not Found"
    }
}

# Figure out path to StifleR.ClientApp.exe.Config (and abort if errors are found)
Write-Log "Looking for StifleR Client installation"
$Service = Get-CimInstance -ClassName Win32_service -Filter "Name = '$ServiceName'"
If ($Service){
    $InstallPath = (Split-Path -Path $($Service.PathName)).Trim('"')
    $StifleRConfig = "$InstallPath\StifleR.ClientApp.exe.Config"
    Write-Log "StifleR Client installation found in: $InstallPath"
    Write-Log "StifleR Client config file is: StifleR.ClientApp.exe.Config"
    Write-Log "Now verifying StifleR Client config file exist..."
    if (Test-path $StifleRConfig){
        Write-Log "StifleR Client Config file found in: $InstallPath"
    }
    Else{
        Write-Log "StifleR Client Config file not found, assuming broken installation, aborting script."
        Break
    }

}
Else{
    Write-Log "StifleR Client not found, aborting script!"
     Break
}

# Validate StifleR Client Config file (and abort if errors are found)
$StiflerConfigItems = (Get-AppSetting $StifleRConfig).count
If ($StiflerConfigItems -lt 30){
    Write-Log "Only found $StiflerConfigItems items in StifleR Client Config file, assuming broken installation, aborting script!"
    Break
}
Else{
    Write-Log "Found $StiflerConfigItems items in StifleR Client Config file, all OK so far."
}



$CurrentValue = (Get-Appsetting $StifleRConfig | where {$_.key -eq "$SettingName"}).value 
# First, see if there is an existing value we can update
If ($CurrentValue){
    # Existing value found
    Write-Log "Existing $SettingName value found: $CurrentValue"
    Write-Log "$SettingName value to set is: $DesiredValue"
    
    # Check if the value needs to change
    If ($CurrentValue -eq $DesiredValue){
        Write-Log "$SettingNames value is already set correcly, do nothing"
        $Compliance = "Compliant"
    }
    Else{
        Write-Log "Setting $SettingName value to: $DesiredValue"
    }
}


Return $Compliance