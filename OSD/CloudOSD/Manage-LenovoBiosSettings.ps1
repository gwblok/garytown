function Manage-LenovoBIOSSettings {
<#
    .DESCRIPTION
        Automatically configure Lenovo BIOS settings

    .PARAMETER GetSettings
        Instruct the script to get a list of current BIOS settings

    .PARAMETER SetSettings
        Instruct the script to set BIOS settings

    .PARAMETER CsvPath
        The path to the CSV file to be imported or exported

    .PARAMETER SupervisorPassword
        The current supervisor password

    .PARAMETER SystemManagementPassword
        The current system management password
    
    .PARAMETER SetDefaults
        Instructs the script to set all BIOS settings to default values

    .PARAMETER LogFile
        Specify the name of the log file along with the full path where it will be stored. The file must have a .log extension. During a task sequence the path will always be set to _SMSTSLogPath

    .EXAMPLE
        #Set BIOS settings supplied in the script when no password is set
        Manage-LenovoBiosSettings.ps1 -SetSettings
    
        #Set BIOS settings supplied in the script when the supervisor password is set
        Manage-LenovoBiosSettings.ps1 -SetSettings -SupervisorPassword ExamplePassword

        #Set BIOS settings supplied in the script when the system management password is set
        Manage-LenovoBiosSettings.ps1 -SetSettings -SystemManagementPassword ExamplePassword

        #Set BIOS settings supplied in a CSV file
        Manage-LenovoBiosSettings.ps1 -SetSettings -CsvPath C:\Temp\Settings.csv -SupervisorPassword ExamplePassword

        #Output a list of current BIOS settings to the screen
        Manage-LenovoBiosSettings.ps1 -GetSettings

        #Output a list of current BIOS settings to a CSV file
        Manage-LenovoBiosSettings.ps1 -GetSettings -CsvPath C:\Temp\Settings.csv

        #Set all BIOS settings to factory default values when the supervisor password is set
        Manage-LenovoBiosSettings.ps1 -SetDefaults -SupervisorPassword ExamplePassword

    .NOTES
        Created by: Jon Anderson (@ConfigJon)
        Reference: https://www.configjon.com/lenovo-bios-settings-management/
        Modified: 2020-10-18

    .CHANGELOG
        2019-11-04 - Added additional logging. Changed the default log path to $ENV:ProgramData\BiosScripts\Lenovo.
        2020-02-10 - Fixed a bug where the script would ignore the supplied Supervisior Password when attempting to change settings.
        2020-02-21 - Added the ability to get a list of current BIOS settings on a system via the GetSettings parameter
                     Added the ability to read settings from or write settings to a csv file with the CsvPath parameter
                     Added the SetSettings parameter to indicate that the script should attempt to set settings
                     Changed the $Settings array in the script to be comma seperated instead of semi-colon seperated
                     Updated formatting
        2020-09-16 - Added a LogFile parameter. Changed the default log path in full Windows to $ENV:ProgramData\ConfigJonScripts\Lenovo.
                     Consolidated duplicate code into new functions (Stop-Script, Get-WmiData). Made a number of minor formatting and syntax changes
                     Updated the save BIOS settings section with better logic to work when a password is set.
                     Added support for for using the system management password
        2020-10-18 - Added the SetDefaults parameter. This allows for setting all BIOS settings to default values.

#>

#Parameters ===================================================================================================================

param(
    [Parameter(Mandatory=$false)][Switch]$GetSettings,
    [Parameter(Mandatory=$false)][Switch]$SetSettings,
    [Parameter(Mandatory=$false)][Switch]$SetDefaults,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$SupervisorPassword,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$SystemManagementPassword,
    [ValidateScript({
        if($_ -notmatch "(\.csv)")
        {
            throw "The specified file must be a .csv file"
        }
        return $true 
    })]
    [System.IO.FileInfo]$CsvPath,
    [Parameter(Mandatory=$false)][ValidateScript({
        if($_ -notmatch "(\.log)")
        {
            throw "The file specified in the LogFile paramter must be a .log file"
        }
        return $true
    })]
    [System.IO.FileInfo]$LogFile = "$ENV:ProgramData\Lenovo\Manage-LenovoBiosSettings.log"
)
$script:LogFile = $LogFile
#List of settings to be configured ============================================================================================
#==============================================================================================================================
$Settings = (
    "PXE IPV4 Network Stack,Enabled",
    "IPv4NetworkStack,Enable",
    "PXEIPV4NetworkStack,Enabled",
    
    "PXE IPV6 Network Stack,Enabled",
    "IPv6NetworkStack,Enable",
    "PXEIPV6NetworkStack,Enabled",

    "Intel(R) Virtualization Technology,Enabled",
    "VirtualizationTechnology,Enabled",
    "VT-d,Enabled",
    "VTdFeature,Enabled",
    "HyperThreadingTechnology,Enabled",
    
    "Enhanced Power Saving Mode,Disabled",
    "EnhancedPowerSavingMode,Disabled",
    
    "Wake on LAN,Automatic",
    #"Require Admin. Pass. For F12 Boot,Yes",
    "Physical Presence for Provisioning,Disabled",
    "PhysicalPresenceForTpmProvision,Disable",
    "Physical Presnce for Clear,Disabled",
    "PhysicalPresenceForTpmClear,Disable",
    "Boot Up Num-Lock Status,Off",

    
    "SecureBoot,Enabled",
    "FastBoot,Disabled",
    
    "WindowsUEFIFirmwareUpdate,Enabled"
)
#==============================================================================================================================
#==============================================================================================================================

#Functions ====================================================================================================================

Function Get-TaskSequenceStatus
{
    #Determine if a task sequence is currently running
	try
	{
		$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
	}
	catch{}
	if($NULL -eq $TSEnv)
	{
		return $False
	}
	else
	{
		try
		{
			$SMSTSType = $TSEnv.Value("_SMSTSType")
		}
		catch{}
		if($NULL -eq $SMSTSType)
		{
			return $False
		}
		else
		{
			return $True
		}
	}
}

Function Stop-Script
{
    #Write an error to the log file and terminate the script

    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$ErrorMessage,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$Exception
    )
    Write-LogEntry -Value $ErrorMessage -Severity 3
    if($Exception)
    {
        Write-LogEntry -Value "Exception Message: $Exception" -Severity 3
    }
    throw $ErrorMessage
}

Function Get-WmiData
{
	#Gets WMI data using either the WMI or CIM cmdlets and stores the data in a variable

    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$Namespace,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$ClassName,
        [Parameter(Mandatory=$true)][ValidateSet('CIM','WMI')]$CmdletType,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String[]]$Select
    )
    try
    {
        if($CmdletType -eq "CIM")
        {
            if($Select)
            {
				Write-LogEntry -Value "Get the $Classname WMI class from the $Namespace namespace and select properties: $Select" -Severity 1
                $Query = Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction Stop | Select-Object $Select -ErrorAction Stop
            }
            else
            {
				Write-LogEntry -Value "Get the $ClassName WMI class from the $Namespace namespace" -Severity 1
                $Query = Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction Stop
            }
        }
        elseif($CmdletType -eq "WMI")
        {
            if($Select)
            {
				Write-LogEntry -Value "Get the $Classname WMI class from the $Namespace namespace and select properties: $Select" -Severity 1
                $Query = Get-WmiObject -Namespace $Namespace -Class $ClassName -ErrorAction Stop | Select-Object $Select -ErrorAction Stop
            }
            else
            {
				Write-LogEntry -Value "Get the $ClassName WMI class from the $Namespace namespace" -Severity 1
                $Query = Get-WmiObject -Namespace $Namespace -Class $ClassName -ErrorAction Stop
            }
        }
    }
    catch
    {
        if($Select)
        {
            Stop-Script -ErrorMessage "An error occurred while attempting to get the $Select properties from the $Classname WMI class in the $Namespace namespace" -Exception $PSItem.Exception.Message
        }
        else
        {
            Stop-Script -ErrorMessage "An error occurred while connecting to the $Classname WMI class in the $Namespace namespace" -Exception $PSItem.Exception.Message	
        }
    }
    Write-LogEntry -Value "Successfully connected to the $ClassName WMI class" -Severity 1
    return $Query
}

Function Set-LenovoBiosSetting
{
    #Set a specific Lenovo BIOS setting

    param(
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$Name,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$Value,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$Password,
        [Parameter(Mandatory=$false)][Switch]$Defaults
    )
    if($Defaults)
    {
        if(!([String]::IsNullOrEmpty($Password)))
        {
            $SettingResult = ($DefaultSettings.LoadDefaultSettings("$Password,ascii,us")).Return
        }
        else
        {
            $SettingResult = ($DefaultSettings.LoadDefaultSettings()).Return
        }
        if($SettingResult -eq "Success")
        {
            Write-LogEntry -Value "Successfully loaded default BIOS settings" -Severity 1
            $Script:DefaultSet = $True
        }
        else
        {
            Write-LogEntry -Value "Failed to load default BIOS settings. Return code: $SettingResult" -Severity 3
            $Script:DefaultSet = $False
        }
    }
    else
    {
        #Ensure the specified setting exists and get the possible values
        $CurrentSetting = $SettingList | Where-Object CurrentSetting -Like "$Name*" | Select-Object -ExpandProperty CurrentSetting
        if($NULL -ne $CurrentSetting)
        {
            #Check how the CurrentSetting data is formatted, then split the setting and current value
            if($CurrentSetting -match ';')
            {
                $FormattedSetting = $CurrentSetting.Substring(0, $CurrentSetting.IndexOf(';'))
                $CurrentSettingSplit = $FormattedSetting.Split(',')
            }
            else
            {
                $CurrentSettingSplit = $CurrentSetting.Split(',')
            }
            #Setting is already set to specified value
            if($CurrentSettingSplit[1] -eq $Value)
            {
                Write-LogEntry -Value "Setting ""$Name"" is already set to ""$Value""" -Severity 1
                $Script:AlreadySet++
            }
            #Setting is not set to specified value
            else
            {
                if(!([String]::IsNullOrEmpty($Password)))
                {
                    $SettingResult = ($Interface.SetBIOSSetting("$Name,$Value,$Password,ascii,us")).Return
                }
                else
                {
                    $SettingResult = ($Interface.SetBIOSSetting("$Name,$Value")).Return
                }
                if($SettingResult -eq "Success")
                {
                    Write-LogEntry -Value "Successfully set ""$Name"" to ""$Value""" -Severity 1
                    $Script:SuccessSet++
                }
                else
                {
                    Write-LogEntry -Value "Failed to set ""$Name"" to ""$Value"". Return code: $SettingResult" -Severity 3
                    $Script:FailSet++
                }
            }
        }
        #Setting not found
        else
        {
            Write-LogEntry -Value "Setting ""$Name"" not found" -Severity 2
            $Script:NotFound++
        }
    }
}

Function Write-LogEntry
{
    #Write data to a CMTrace compatible log file. (Credit to SCConfigMgr - https://www.scconfigmgr.com/)

	param(
		[parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("1", "2", "3")]
		[string]$Severity,
		[parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
		[ValidateNotNullOrEmpty()]
		[string]$FileName = ($script:LogFile | Split-Path -Leaf)
	)
    #Determine log file location
    $LogFilePath = Join-Path -Path $LogsDirectory -ChildPath $FileName
    #Construct time stamp for log entry
    if(-not(Test-Path -Path 'variable:global:TimezoneBias'))
    {
        [string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
        if($TimezoneBias -match "^-")
        {
            $TimezoneBias = $TimezoneBias.Replace('-', '+')
        }
        else
        {
            $TimezoneBias = '-' + $TimezoneBias
        }
    }
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), $TimezoneBias)
    #Construct date for log entry
    $Date = (Get-Date -Format "MM-dd-yyyy")
    #Construct context for log entry
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    #Construct final log entry
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""Manage-LenovoBiosSettings"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
    #Add value to log file
    try
    {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception]
    {
        Write-Warning -Message "Unable to append log entry to $FileName file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
}

#Main program =================================================================================================================

#Configure Logging and task sequence variables
if(Get-TaskSequenceStatus)
{
	$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
	$LogsDirectory = $TSEnv.Value("_SMSTSLogPath")
}
else
{
	$LogsDirectory = ($LogFile | Split-Path)
    if([string]::IsNullOrEmpty($LogsDirectory))
    {
        $LogsDirectory = $PSScriptRoot
    }
    else
    {
        if(!(Test-Path -PathType Container $LogsDirectory))
        {
            try
            {
                New-Item -Path $LogsDirectory -ItemType "Directory" -Force -ErrorAction Stop | Out-Null
            }
            catch
            {
                throw "Failed to create the log file directory: $LogsDirectory. Exception Message: $($PSItem.Exception.Message)"
            }
        }
    }
}
Write-Output "Log path set to $LogFile"
Write-LogEntry -Value "START - Lenovo BIOS settings management script" -Severity 1

#Parameter validation
Write-LogEntry -Value "Begin parameter validation" -Severity 1
if($GetSettings -and ($SetSettings -or $SetDefaults))
{
    Stop-Script -ErrorMessage "Cannot specify the GetSettings and SetSettings or SetDefaults parameters at the same time"
}
if(!($GetSettings -or $SetSettings -or $SetDefaults))
{
    Stop-Script -ErrorMessage "One of the GetSettings or SetSettings or SetDefaults parameters must be specified when running this script"
}
if($SetSettings -and !($Settings -or $CsvPath))
{
    Stop-Script -ErrorMessage "Settings must be specified using either the Settings variable in the script or the CsvPath parameter"
}
if($SetSettings -and $SetDefaults)
{
	$ErrorMsg = "Both the SetSettings and SetDefaults parameters have been used. The SetDefaults parameter will override any other settings"
    Write-LogEntry -Value $ErrorMsg -Severity 2
}
if(($SetDefaults -and $CsvPath) -and !($SetSettings))
{
	$ErrorMsg = "The CsvPath parameter has been specified without the SetSettings paramter. The CSV file will be ignored"
    Write-LogEntry -Value $ErrorMsg -Severity 2
}
Write-LogEntry -Value "Parameter validation completed" -Severity 1

#Connect to the Lenovo_BiosSetting WMI class
$SettingList = Get-WmiData -Namespace root\wmi -ClassName Lenovo_BiosSetting -CmdletType WMI

#Connect to the Lenovo_SetBiosSetting WMI class
$Interface = Get-WmiData -Namespace root\wmi -ClassName Lenovo_SetBiosSetting -CmdletType WMI

#Connect to the Lenovo_SaveBiosSettings WMI class
$SaveSettings = Get-WmiData -Namespace root\wmi -ClassName Lenovo_SaveBiosSettings -CmdletType WMI

#Connect to the Lenovo_BiosPasswordSettings WMI class
$PasswordSettings = Get-WmiData -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings -CmdletType WMI

#Connect to the Lenovo_SetBiosPassword WMI class
$PasswordSet = Get-WmiData -Namespace root\wmi -ClassName Lenovo_SetBiosPassword -CmdletType WMI

#Connect to the Lenovo_SetBiosPassword WMI class
if($SetDefaults)
{
    $DefaultSettings = Get-WmiData -Namespace root\wmi -ClassName Lenovo_LoadDefaultSettings -CmdletType WMI
}

#Set counters to 0
if($SetSettings -or $SetDefaults)
{
    $Script:AlreadySet = 0
    $Script:SuccessSet = 0
    $Script:FailSet = 0
    $Script:NotFound = 0
    $Script:DefaultSet = $Null
}




#Get the current password state
Write-LogEntry -Value "Get the current password state" -Severity 1
switch($PasswordSettings.PasswordState)
{
	{$_ -eq 0}
	{
		Write-LogEntry -Value "No passwords are currently set" -Severity 1
	}
	{($_ -eq 2) -or ($_ -eq 3) -or ($_ -eq 6) -or ($_ -eq 7) -or ($_ -eq 66) -or ($_ -eq 67) -or ($_ -eq 70) -or ($_-eq 71)}
	{
		$SvpSet = $true
		Write-LogEntry -Value "The supervisor password is set" -Severity 1
	}
	{($_ -eq 64) -or ($_ -eq 65) -or ($_ -eq 66) -or ($_ -eq 67) -or ($_ -eq 68) -or ($_ -eq 69) -or ($_ -eq 70) -or ($_-eq 71)}
	{
		$SmpSet = $true
		Write-LogEntry -Value "The system management password is set" -Severity 1
	}
	default
	{
		Stop-Script -ErrorMessage "Unable to determine the current password state from value: $($PasswordSettings.PasswordState)"
	}
}

#Ensure passwords are set correctly
if($SetSettings -or $SetDefaults)
{
    if($SvpSet)
    {
        Write-LogEntry -Value "Ensure the supplied supervisor password is correct" -Severity 1
        #Supervisor password set but parameter not specified
        if([String]::IsNullOrEmpty($SupervisorPassword))
        {
            Stop-Script -ErrorMessage "The supervisor password is set, but no password was supplied. Use the SupervisorPassword parameter when a password is set"
        }
        #Supervisor password set correctly
        if($PasswordSet.SetBiosPassword("pap,$SupervisorPassword,$SupervisorPassword,ascii,us").Return -eq "Success")
	    {
		    Write-LogEntry -Value "The specified supervisor password matches the currently set password" -Severity 1
        }
        #Supervisor password not set correctly
        else
        {
            Stop-Script -ErrorMessage "The specified supervisor password does not match the currently set password"
        }
    }
    elseif($SmpSet -and !$SvpSet)
    {
        Write-LogEntry -Value "Ensure the supplied system management password is correct" -Severity 1
        #System management password set but parameter not specified
        if([String]::IsNullOrEmpty($SystemManagementPassword))
        {
            Stop-Script -ErrorMessage "The system management password is set, but no password was supplied. Use the SystemManagementPassword parameter when a password is set"
        }
        #System management password set correctly
        if($PasswordSet.SetBiosPassword("smp,$SystemManagementPassword,$SystemManagementPassword,ascii,us").Return -eq "Success")
	    {
		    Write-LogEntry -Value "The specified system management password matches the currently set password" -Severity 1
        }
        #System management password not set correctly
        else
        {
            Stop-Script -ErrorMessage "The specified system management password does not match the currently set password"
        }
    }
}

#Get settings
if($GetSettings)
{
    $SettingList = $SettingList | Select-Object CurrentSetting | Sort-Object CurrentSetting
    $SettingObject = ForEach($Setting in $SettingList){
        #Split the current values
        $SettingSplit = ($Setting.CurrentSetting).Split(',')
        if($SettingSplit[0] -and $SettingSplit[1])
        {
            [PSCustomObject]@{
                Name = $SettingSplit[0]
                Value = $SettingSplit[1]
            }
        }
    }
    if($CsvPath)
    {
        $SettingObject | Export-Csv -Path $CsvPath -NoTypeInformation
        (Get-Content $CsvPath) | ForEach-Object {$_ -Replace '"',""} | Out-File $CsvPath -Force -Encoding ascii
    }
    else
    {
        Write-Output $SettingObject    
    }
}
#Set Settings
if($SetSettings -or $SetDefaults)
{
    if($CsvPath)
    {
        Clear-Variable Settings -ErrorAction SilentlyContinue
        $Settings = Import-Csv -Path $CsvPath
    }
    #Set Lenovo BIOS settings - supervisor password is set
    if($SvpSet)
    {
        if($SetSettings)
        {
            if($CsvPath)
            {
                ForEach($Setting in $Settings){
                    Set-LenovoBiosSetting -Name $Setting.Name -Value $Setting.Value -Password $SupervisorPassword
                }
            }
            else
            {
                ForEach($Setting in $Settings){
                    $Data = $Setting.Split(',')
                    Set-LenovoBiosSetting -Name $Data[0] -Value $Data[1].Trim() -Password $SupervisorPassword
                }
            }
        }
        if($SetDefaults)
        {
            Set-LenovoBiosSetting -Defaults -Password $SupervisorPassword
        }
    }
    #Set Lenovo BIOS settings - system management password is set
    elseif($SmpSet -and !$SvpSet)
    {
        if($SetSettings)
        {
            if($CsvPath)
            {
                ForEach($Setting in $Settings){
                    Set-LenovoBiosSetting -Name $Setting.Name -Value $Setting.Value -Password $SystemManagementPassword
                }
            }
            else
            {
                ForEach($Setting in $Settings){
                    $Data = $Setting.Split(',')
                    Set-LenovoBiosSetting -Name $Data[0] -Value $Data[1].Trim() -Password $SystemManagementPassword
                }
            }
        }
        if($SetDefaults)
        {
            Set-LenovoBiosSetting -Defaults -Password $SystemManagementPassword
        }
    }
    #Set Lenovo BIOS settings - password is not set
    else
    {
        if($SetSettings)
        {
            if($CsvPath)
            {
                ForEach($Setting in $Settings){
                    Set-LenovoBiosSetting -Name $Setting.Name -Value $Setting.Value
                }
            }
            else
            {
                ForEach($Setting in $Settings){
                    $Data = $Setting.Split(',')
                    Set-LenovoBiosSetting -Name $Data[0] -Value $Data[1].Trim()
                }
            }
        }
        if($SetDefaults)
        {
            Set-LenovoBiosSetting -Defaults
        }
    }
}

#If settings were set, save the changes
if(($SuccessSet -gt 0) -or ($DefaultSet -eq $True))
{
    Write-LogEntry -Value "Save the BIOS settings changes" -Severity 1
    if($SvpSet)
    {
        $ReturnCode = ($SaveSettings.SaveBiosSettings("$SupervisorPassword,ascii,us")).Value
    }
    elseif($SmpSet -and !$SvpSet)
    {
        $ReturnCode = ($SaveSettings.SaveBiosSettings("$SystemManagementPassword,ascii,us")).Value
    }
    else
    {
        $ReturnCode = ($SaveSettings.SaveBiosSettings()).Value
    }
    if(($null -eq $ReturnCode) -or ($ReturnCode -eq "Success"))
    {
        Write-LogEntry -Value "Successfully saved the BIOS settings" -Severity 1
    }
    else
    {
        Stop-Script -ErrorMessage "Failed to save the BIOS settings. Return Code: $ReturnCode"
    }
}

#Display results
if($SetSettings)
{
    Write-Output "$AlreadySet settings already set correctly"
    Write-LogEntry -Value "$AlreadySet settings already set correctly" -Severity 1
    Write-Output "$SuccessSet settings successfully set"
    Write-LogEntry -Value "$SuccessSet settings successfully set" -Severity 1
    Write-Output "$FailSet settings failed to set"
    Write-LogEntry -Value "$FailSet settings failed to set" -Severity 3
    Write-Output "$NotFound settings not found"
    Write-LogEntry -Value "$NotFound settings not found" -Severity 2
}
if($SetDefaults)
{
    if($DefaultSet -eq $True)
    {
        Write-Output "Successfully loaded default BIOS settings"
    }
    else
    {
        Write-Output "Failed to load default BIOS settings"
    }
}
Write-Output "Lenovo BIOS settings Management completed. Check the log file for more information"
Write-LogEntry -Value "END - Lenovo BIOS settings management script" -Severity 1
}
