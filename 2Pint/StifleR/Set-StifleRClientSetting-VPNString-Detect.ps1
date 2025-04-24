# Script to check the StifleR Client VPNString
# NOTE: Using sc.exe stop/start the service, and query service state, rather than PS or .NET (We found it more reliable)

# Variables
$ServiceName = "StifleRClient"
$LogPath = "$env:ProgramData\Intune\StifleRClientConfiguration_Discovery.log"
$Compliance = "Non-Compliant" # Assume non-compliant, if running script multiple times
$SettingName = 'VPNStrings'
$DesiredValue = "Citrix VPN, Cisco AnyConnect, WireGuard"
# Delete any existing logfile if it exists
If (Test-Path $LogPath){Remove-Item $LogPath -Force -ErrorAction SilentlyContinue -Confirm:$false}

Function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$false)]
        $Component = "Script",
        [Parameter(Mandatory=$false)]
        [int]$Type,
        [Parameter(Mandatory=$false)]
        $LogFile = $LogPath
    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
    $Time = Get-Date -Format "HH:mm:ss.ffffff"
    $Date = Get-Date -Format "MM-dd-yyyy"
    if ($ErrorMessage -ne $null) {$Type = 3}
    if ($Component -eq $null) {$Component = " "}
    if ($Type -eq $null) {$Type = 1}
    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}
if (Test-Path -Path "$env:ProgramData\Intune" -eq $false) {
    New-Item -Path "$env:ProgramData\Intune" -ItemType Directory -Force | Out-Null
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