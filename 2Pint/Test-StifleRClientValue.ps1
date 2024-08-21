# Script to check the StifleR Client VPNString
# NOTE: Using sc.exe stop/start the service, and query service state, rather than PS or .NET (We found it more reliable)

# Variables
$ServiceName = "StifleRClient"
#$LogPath = "C:\Windows\Temp\StifleRClientConfiguration_Discovery.log"
$SettingName = 'StiflerServers'
$DesiredValue = "https://2PStifleR.2p.garytown.com:1414"
#$CompliantVPNString = "Cisco AnyConnect" # Edit this for your VPN provider
$Compliance = "Non-Compliant" # Assume non-compliant, if running script multiple times



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
        Write-Output "Configuration File $PathToConfig Not Found"
    }
}

# Figure out path to StifleR.ClientApp.exe.Config (and abort if errors are found)
Write-Output "Looking for StifleR Client installation"
$Service = Get-CimInstance -ClassName Win32_service -Filter "Name = '$ServiceName'"
If ($Service){
    $InstallPath = (Split-Path -Path $($Service.PathName)).Trim('"')
    $StifleRConfig = "$InstallPath\StifleR.ClientApp.exe.Config"
    Write-Output "StifleR Client installation found in: $InstallPath"
    Write-Output "StifleR Client config file is: StifleR.ClientApp.exe.Config"
    Write-Output "Now verifying StifleR Client config file exist..."
    if (Test-path $StifleRConfig){
        Write-Output "StifleR Client Config file found in: $InstallPath"
    }
    Else{
        Write-Output "StifleR Client Config file not found, assuming broken installation, aborting script."
        Break
    }

}
Else{
    Write-Output "StifleR Client not found, aborting script!"
     Break
}

# Validate StifleR Client Config file (and abort if errors are found)
$StiflerConfigItems = (Get-AppSetting $StifleRConfig).count
If ($StiflerConfigItems -lt 30){
    Write-Output "Only found $StiflerConfigItems items in StifleR Client Config file, assuming broken installation, aborting script!"
    Break
}
Else{
    Write-Output "Found $StiflerConfigItems items in StifleR Client Config file, all OK so far."
}

# Check the Setting String value
$CurrentValue = (Get-Appsetting $StifleRConfig | where {$_.key -eq $SettingName}).value 
Write-Output "Current $SettingName value is: $CurrentValue"
If ($CurrentValue -eq $DesiredValue){
    Write-Output "Compliant $SettingName value is: $CurrentValue. All OK, return compliant"
    $Compliance = "Compliant"
}
Else {
    Write-Output "Compliant $SettingName value is: $CurrentValue. We are Not compliant, return nothing"
}

Return $Compliance
