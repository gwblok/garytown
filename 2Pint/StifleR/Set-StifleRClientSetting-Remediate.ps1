# Script to update the StifleR client Config file
# NOTE: Using sc.exe stop/start the service, and query service state, rather than PS or .NET (We found it more reliable)

# Variables
$ServiceName = "StifleRClient"
$SCStartCmd = {sc.exe start $ServiceName}
$SCQueryCmd = {sc.exe query $ServiceName}
$SCStopCmd = {sc.exe stop $ServiceName}
$LogPath = "$env:ProgramData\Intune\StifleRClientConfiguration_Remediation.log"
$SettingName = 'StiflerServers'
$DesiredValue = "https://2PSR210.2p.garytown.com:1414"
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

Function Get-AppSetting{
    param (
    [Parameter(Mandatory = $true)]
    [string]$PathToConfig
    )

    if (Test-Path $PathToConfig)
    {
        $x =  [Xml] (type $PathToConfig)
        $x.configuration.appSettings.add
    }
    else{
        Write-Log "Get-Appsetting: Configuration File $PathToConfig Not Found"
    }
}
if (Test-Path -Path "$env:ProgramData\Intune" -eq $false) {
    New-Item -Path "$env:ProgramData\Intune" -ItemType Directory -Force | Out-Null
}
function Set-AppSetting{
    param (
    [Parameter(Mandatory = $true)]
    [string]$PathToConfig,
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [Parameter(Mandatory = $true)]
    [string]$Value
    )

    Write-Log "Set-Appsetting: PathToConfig set to: $PathToConfig"
    Write-Log "Set-Appsetting: Key set to: $Key"
    Write-Log "Set-Appsetting: Valueset to: $Value"
    
    if (Test-Path $PathToConfig){
        $x = [xml] (type $PathToConfig)
        $node = $x.configuration.SelectSingleNode("appSettings/add[@key='$Key']")
        $node.value = $Value
        $x.Save($PathToConfig)
    }
    else{
        Write-Log "Set-Appsetting: Configuration File $PathToConfig Not Found"
    }

}

function New-AppSetting {
    param (
    [Parameter(Mandatory = $true)]
    [string]$PathToConfig,
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [Parameter(Mandatory = $true)]
    [string]$Value
    )

    Write-Log "New-Appsetting: PathToConfig set to: $PathToConfig"
    Write-Log "New-Appsetting: Key set to: $Key"
    Write-Log "New-Appsetting: Valueset to: $Value"

	if (Test-Path $PathToConfig){	
		$x = [xml] (type $PathToConfig)
		$el = $x.CreateElement("add")
		$kat = $x.CreateAttribute("key")
		$kat.psbase.value = $Key
		$vat = $x.CreateAttribute("value")
		$vat.psbase.value = $Value
		$el.SetAttributeNode($kat)
		$el.SetAttributeNode($vat)
		$x.configuration.appSettings.Appendchild($el)
		$x.Save($PathToConfig) 
	}
    else{
        Write-Log "New-Appsetting: Configuration File $PathToConfig Not Found"
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

# Stop the service
$SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
$State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
write-Log "The current state of the service is: $State"
If($State -eq "STOPPED"){
    write-Log "Service is already stopped, continue to next section."
}
Else {
    write-Log "Service is running, trying to stop it."
    Invoke-Command -ScriptBlock $SCStopCmd | Out-Null
    $loopCounter=0
    do 
    { 
        $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
        $State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
        Start-Sleep -Seconds 5
        $loopCounter++
        write-Log "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed"

    } until (($State -eq "STOPPED") -or $loopcounter -eq 12)
    
    # Service should be stopped now, abort if its not
    If($State -eq "STOPPED"){
        write-Log "Service stopped, all Ok to continue."
    }
    Else{
        write-Log "Service could not be stopped, aborting script."
        Break
    }
}

# Backup the existing StifleR config XML before modifying it
Write-Log "Backing up the existing StifleR config XML to $InstallPath\Backup"
If (!(Test-Path "$InstallPath\Backup")){
    New-Item -Path "$InstallPath\Backup" -ItemType Directory
}
$BackupStifleRConfig = "$InstallPath\Backup\StifleR.ClientApp.exe.Config"
Copy-Item $StifleRConfig $BackupStifleRConfig -Force
<#
# Configure the VPNStrings value in the backup file
$VPNStrings = (Get-Appsetting $BackupStifleRConfig | where {$_.key -eq "VPNStrings"}).value 
# First, see if there is an existing value we can update
If ($VPNStrings){
    # Existing value found
    Write-Log "Existing VPNStrings value found: $VPNStrings"
    Write-Log "VPNString value to set is: $VPNString"
    
    # Check if the value needs to change
    If ($VPNStrings -eq $VPNString){
        Write-Log "VPNStrings value is already set correcly, do nothing"
    }
    Else{
        Write-Log "Setting VPNStrings value to: $VPNString"
        Set-AppSetting $BackupStifleRConfig "VPNStrings" $VPNString | Out-Null    
    }
}
Else {
    # No existing VPNStrings value found, adding a new key with the value
    Write-Log "No VPNStrings value found, creating a new VPNStrings key and set the value"
    New-AppSetting $BackupStifleRConfig "VPNStrings" "$VPNString" | Out-Null    
}
#>


# Configure the VPNStrings value in the backup file
$CurrentValue = (Get-Appsetting $BackupStifleRConfig | where {$_.key -eq "$SettingName"}).value 
# First, see if there is an existing value we can update
If ($CurrentValue){
    # Existing value found
    Write-Log "Existing $SettingName value found: $CurrentValue"
    Write-Log "$SettingName value to set is: $DesiredValue"
    
    # Check if the value needs to change
    If ($CurrentValue -eq $DesiredValue){
        Write-Log "$SettingNames value is already set correcly, do nothing"
    }
    Else{
        Write-Log "Setting $SettingName value to: $DesiredValue"
        Set-AppSetting $BackupStifleRConfig "$SettingName" $DesiredValue | Out-Null    
    }
}
Else {
    # No existing $SettingName value found, adding a new key with the value
    Write-Log "No $SettingName value found, creating a new $SettingName key and set the value"
    New-AppSetting $BackupStifleRConfig "$SettingName" "$DesiredValue" | Out-Null    
}

# Validate StifleR Client Config file after edit, and restore the backup if it looks ok
$StiflerConfigItems = (Get-AppSetting $BackupStifleRConfig).count
If ($StiflerConfigItems -lt 30){
    Write-Log "Only found $StiflerConfigItems items in StifleR Client Config file, assuming broken, don't restore it"
}
Else{
    Write-Log "Found $StiflerConfigItems items in StifleR Client Config file, all OK so far. Restoring the file"
    Copy-Item $BackupStifleRConfig $StifleRConfig -Force
}

# Start the StifleRClient service
$SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
$State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
write-Log "The current state of the service is: $State"
If($State -eq "RUNNING"){
    write-Log "Service is already running, continue to next section."
}
Else {
    write-Log "Service is stopped, trying to start it."
    Invoke-Command -ScriptBlock $SCStartCmd | Out-Null
    $loopCounter=0
    do 
    { 
        $SvcStatus = Invoke-Command -ScriptBlock $SCQueryCmd
        $State = $SvcStatus | Select-String "STATE" | ForEach-Object { ($_ -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1 }
        Start-Sleep -Seconds 5
        $loopCounter++
        write-Log "Waiting for Service to stop: $($loopcounter * 5) Seconds Elapsed"

    } until (($State -eq "RUNNING") -or $loopCounter -eq 12)

    # Service should be running now, abort if its not, and log an error
    If($State -eq "RUNNING"){
        write-Log "Service running, all Ok to continue."
    }
    Else{
        write-Log "ERROR: Service could not be started, not good, aborting script."
        Break
    }

}
