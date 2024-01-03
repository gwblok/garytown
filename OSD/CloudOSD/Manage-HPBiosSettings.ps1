#Modified version of Jon's Script - https://www.configjon.com/hp-bios-settings-management/
function Manage-HPBiosSettings{<#
    .DESCRIPTION
        Automatically configure HP BIOS settings

        SetBIOSSetting Return Codes
        0 - Success
        1 - Not Supported
        2 - Unspecified Error
        3 - Timeout
        4 - Failed - (Check for typos in the setting value)
        5 - Invalid Parameter
        6 - Access Denied - (Check that the BIOS password is correct)
    
    .PARAMETER GetSettings
        Instruct the script to get a list of current BIOS settings

    .PARAMETER SetSettings
        Instruct the script to set BIOS settings

    .PARAMETER CsvPath
        The path to the CSV file to be imported or exported

    .PARAMETER SetupPassword
        The current BIOS password

    .PARAMETER LogFile
        Specify the name of the log file along with the full path where it will be stored. The file must have a .log extension. During a task sequence the path will always be set to _SMSTSLogPath

    .EXAMPLE
        #Set BIOS settings supplied in the script
        Manage-HPBiosSettings.ps1 -SetSettings -SetupPassword ExamplePassword

        #Set BIOS settings supplied in a CSV file
        Manage-HPBiosSettings.ps1 -SetSettings -CsvPath C:\Temp\Settings.csv -SetupPassword ExamplePassword

        #Output a list of current BIOS settings to the screen
        Manage-HPBiosSettings.ps1 -GetSettings

        #Output a list of current BIOS settings to a CSV file
        Manage-HPBiosSettings.ps1 -GetSettings -CsvPath C:\Temp\Settings.csv

    .NOTES
        Created by: Jon Anderson (@ConfigJon)
        Reference: https://www.configjon.com/hp-bios-settings-management/
        Modified: 2020-09-17

    .CHANGELOG
        2019-11-04 - Added additional logging. Changed the default log path to $ENV:ProgramData\BiosScripts\HP.
        2020-02-21 - Added the ability to get a list of current BIOS settings on a system via the GetSettings parameter
                     Added the ability to read settings from or write settings to a csv file with the CsvPath parameter
                     Added the SetSettings parameter to indicate that the script should attempt to set settings
                     Changed the $Settings array in the script to be comma seperated instead of semi-colon seperated
                     Updated formatting
        2020-09-14 - Added a LogFile parameter. Changed the default log path in full Windows to $ENV:ProgramData\ConfigJonScripts\HP.
                     Consolidated duplicate code into new functions (Stop-Script, Get-WmiData). Made a number of minor formatting and syntax changes
        2020-09-17 - Improved the log file path configuration

#>

#Parameters ===================================================================================================================

param(
    [Parameter(Mandatory=$false)][Switch]$GetSettings,
    [Parameter(Mandatory=$false)][Switch]$SetSettings,    
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$SetupPassword,
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
    [System.IO.FileInfo]$LogFile = "$ENV:temp\HP\Manage-HPBiosSettings.log"
)

#List of settings to be configured ============================================================================================
#==============================================================================================================================
$Global:Settings = (
    "Deep S3,Off",
    "Deep Sleep,Off",
    "S4/S5 Max Power Savings,Disable",
    "S5 Maximum Power Savings,Disable",
    "Num Lock State at Power-On,On",
    "NumLock on at boot,Enable",
    "Numlock state at boot,On",
    "PXE Internal IPV4 NIC boot,Enable",
    "PXE Internal NIC boot,Enable",
    "Wake On LAN,Boot to Hard Drive",
    "Swap Fn and Ctrl (Keys),Disable",
    "TPM State,Enable",
    "TPM Device,Available",
    "TPM Activation Policy,No prompts",
    "Lock BIOS Version, Disable",
    "Native OS Firmware Update Service,Enable",
    "Virtualization Technology (VTx),Enable",
    "Virtualization Technology for Directed I/O (VTd),Enable",
    "SVM CPU Virtualization,Enable",
    "Secure Boot,Enable",
    "UEFI Boot Options,Enable",
    "Configure Legacy Support and Secure Boot,Legacy Support Disable and Secure Boot Enable"
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

Function Set-HPBiosSetting
{
    #Set a specific HP BIOS setting

    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$Name,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$Value,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$Password
    )
    #Ensure the specified setting exists and get the possible values
    $CurrentSetting = $SettingList | Where-Object Name -eq $Name | Select-Object -ExpandProperty Value
    if($NULL -ne $CurrentSetting)
    {
        #Split the current values
        $CurrentSettingSplit = $CurrentSetting.Split(',')
        #Find the currently set value
        $Count = 0
        while($Count -lt $CurrentSettingSplit.Count)
        {
            if($CurrentSettingSplit[$Count].StartsWith('*'))
            {
                $CurrentValue = $CurrentSettingSplit[$Count]
                break
            }
            else
            {
                $Count++
            }
        }
        #Setting is already set to specified value
        if($CurrentValue.Substring(1) -eq $Value)
        {
            Write-LogEntry -Value "Setting ""$Name"" is already set to ""$Value""" -Severity 1
            $Script:AlreadySet++
        }
        #Setting is not set to specified value
        else
        {
            if(!([String]::IsNullOrEmpty($Password)))
            {
                $SettingResult = ($Interface.SetBIOSSetting($Name,$Value,"<utf-16/>" + $Password)).Return
            }
            else
            {
                $SettingResult = ($Interface.SetBIOSSetting($Name,$Value)).Return
            }
            if($SettingResult -eq 0)
            {
                Write-LogEntry -Value "Successfully set ""$Name"" to ""$Value""" -Severity 1
                $Script:SuccessSet++
            }
            else
            {
                Write-LogEntry -Value "Failed to set ""$Name"" to ""$Value"". Return code $SettingResult" -Severity 3
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
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""Manage-HPBiosSettings"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
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
Write-LogEntry -Value "START - HP BIOS settings management script" -Severity 1

#Connect to the HP_BIOSEnumeration WMI class
$SettingList = Get-WmiData -Namespace root\hp\InstrumentedBIOS -ClassName HP_BIOSEnumeration -CmdletType WMI

#Connect to the HP_BIOSSettingInterface WMI class
$Interface = Get-WmiData -Namespace root\hp\InstrumentedBIOS -ClassName HP_BIOSSettingInterface -CmdletType WMI

#Connect to the HP_BIOSSetting WMI class
$HPBiosSetting = Get-WmiData -Namespace root\hp\InstrumentedBIOS -ClassName HP_BIOSSetting -CmdletType WMI

#Parameter validation
Write-LogEntry -Value "Begin parameter validation" -Severity 1
if($GetSettings -and $SetSettings)
{
    Stop-Script -ErrorMessage "Cannot specify the GetSettings and SetSettings parameters at the same time"
}
if(!($GetSettings -or $SetSettings))
{
    Stop-Script -ErrorMessage "One of the GetSettings or SetSettings parameters must be specified when running this script"
}
if($SetSettings -and !($Settings -or $CsvPath))
{
    Stop-Script -ErrorMessage "Settings must be specified using either the Settings variable in the script or the CsvPath parameter"
}
Write-LogEntry -Value "Parameter validation completed" -Severity 1

#Set counters to 0
if($SetSettings)
{
    $AlreadySet = 0
    $SuccessSet = 0
    $FailSet = 0
    $NotFound = 0
}

#Get the current password status
if($SetSettings)
{
    Write-LogEntry -Value "Check current BIOS setup password status" -Severity 1
    $PasswordCheck = ($HPBiosSetting | Where-Object Name -eq "Setup Password").IsSet
    if($PasswordCheck -eq 1)
    {
        #Setup password set but parameter not specified
        if([String]::IsNullOrEmpty($SetupPassword))
        {
            Stop-Script -ErrorMessage "The BIOS setup password is set, but no password was supplied. Use the SetupPassword parameter when a password is set"
        }
        #Setup password set correctly
        if(($Interface.SetBIOSSetting("Setup Password","<utf-16/>" + $SetupPassword,"<utf-16/>" + $SetupPassword)).Return -eq 0)
	    {
		    Write-LogEntry -Value "The specified setup password matches the currently set password" -Severity 1
        }
        #Setup password not set correctly
        else
        {
            Stop-Script -ErrorMessage "The specified setup password does not match the currently set password"
        }
    }
    else
    {
        Write-LogEntry -Value "The BIOS setup password is not currently set" -Severity 1
    }
}

#Get the current settings
if($GetSettings)
{
    $SettingList = $SettingList | Select-Object Name,Value | Sort-Object Name
    $SettingObject = ForEach($Setting in $SettingList){
        #Split the current values
        $SettingSplit = ($Setting.Value).Split(',')
        #Find the currently set value
        $SplitCount = 0
        while($SplitCount -lt $SettingSplit.Count)
        {
            if($SettingSplit[$SplitCount].StartsWith('*'))
            {
                $SetValue = ($SettingSplit[$SplitCount]).Substring(1)
                break
            }
            else
            {
                $SplitCount++
            }
        }
        [PSCustomObject]@{
            Name = $Setting.Name
            Value = $SetValue
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
#Set settings
if($SetSettings)
{
    if($CsvPath)
    {
        Clear-Variable Settings -ErrorAction SilentlyContinue
        $Settings = Import-Csv -Path $CsvPath
    }
    #Set HP BIOS settings - password is set
    if($PasswordCheck -eq 1)
    {
        if($CsvPath)
        {
            ForEach($Setting in $Settings){
                Set-HPBiosSetting -Name $Setting.Name -Value $Setting.Value -Password $SetupPassword
            }
        }
        else
        {
            ForEach($Setting in $Settings){
                $Data = $Setting.Split(',')
                Set-HPBiosSetting -Name $Data[0].Trim() -Value $Data[1].Trim() -Password $SetupPassword   
            }
        }
    }
    #Set HP BIOS settings - password is not set
    else
    {
        if($CsvPath)
        {
            ForEach($Setting in $Settings){
                Set-HPBiosSetting -Name $Setting.Name -Value $Setting.Value
            }
        }
        else
        {
            ForEach($Setting in $Settings){
                $Data = $Setting.Split(',')
                Set-HPBiosSetting -Name $Data[0].Trim() -Value $Data[1].Trim()            
            }
        }
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
Write-Output "HP BIOS settings Management completed. Check the log file for more information"
Write-LogEntry -Value "END - HP BIOS settings management script" -Severity 1

}

Manage-HPBiosSettings -SetSettings
