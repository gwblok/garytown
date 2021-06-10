<#
Gary Blok - GARYTOWN.COM - @gwblok

Used for Testing Application Deployment Ideas
This "App" Install Script sets a registry key and that's it... the detection is the registry key
Everything else is testing ideas, changing policies, setting reboots, etc.

Change Log
2020.05.29 - Initial Release of CM App Deployment Testing Script
2021.06.09 - Set Exit code as a Parameter
2021.06.09 - Set Logfile location as Parameter, defaults to %temp% if not specified.
2021.06.09 - Added Function Restart-ComputerCMClient which will trigger the CM Client to restart the machine based on the Client Settings Polic

Examples:
Install Command: powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\FakeApp.ps1 -Method Install -ExitCode 0
Install Command: powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\FakeApp.ps1 -Method Install -ExitCode 3010
Uninstall Command: powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\FakeApp.ps1 -Method Uninstall


Update the $CustomRegistryKeyName variable to match your needs.

App Detection Method:
Registry: HKLM\SOFTWARE\%CUSTOM% | Property: FakeApp | Value: True  #(Replace %CUSTOM% with what you set $CustomRegistryKeyName to)

#>

[CmdletBinding()] 
param (

        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("Install", "Uninstall")][string]$Method,
        [Parameter(Mandatory=$false)][int]$ExitCode,
        [Parameter(Mandatory=$false)][int]$LogFile
    ) 

$CustomRegistryKeyName = "Recast_IT" #Update this, then update your detection method to match
$InstallAssignmentName = "FakeApp" #Used for finding the User Deployment Application Install Policy 
$RegistryPath = "HKLM:\SOFTWARE\$CustomRegistryKeyName"
if (!($LogFile)){$LogFile = "C:\Windows\Temp\FakeApp_Install.log"}
if (!(Test-Path -Path $RegistryPath)){new-item -Path $RegistryPath -ItemType Directory -Force}

#CMTraceLog Function formats logging in CMTrace style
function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $InstallAssignmentName,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile
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
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

#Used to set Exit Code in way that CM registers
function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

#Function that calls the Restart Package Program.  You MUST have set this up and deployed to machines prior to running this, or it won't do anything
function TriggerRebootProgram
    {
    $RestartProgram = Get-CimInstance -ClassName "CCM_SoftwareDistribution" -Namespace "ROOT\ccm\policy\machine\actualconfig" | Where-Object {$_.PKG_Name  -match "Restart Computer" -and $_.PRG_ProgramName -match "Exit Force Restart"}
    if ($RestartProgram)
        {
        CMTraceLog -Message  "Found Restart Package, Triggering Now" -Type 1 -LogFile $LogFile
        $RestartProgramDeployID = $RestartProgram.ADV_AdvertisementID
        $RestartProgramPackageID = $RestartProgram.PKG_PackageID
        $RestartProgramProgramID = $RestartProgram.PRG_ProgramID

        [XML]$XML = $RestartProgram.PRG_Requirements
        $Schedule = $xml.SWDReserved.ScheduledMessageID

        $Program = ([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$($RestartProgramDeployID)',PKG_PackageID='$($RestartProgramPackageID)',PRG_ProgramID='$($RestartProgramProgramID)'")
        $Program.ADV_RepeatRunBehavior = 'RerunAlways'
        $Program.ADV_MandatoryAssignments = 'True'
        $Program.put()

        ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($Schedule)
        }
    else {CMTraceLog -Message  "Did not find Package / Program named: Restart Computer - Exit Force Restart" -Type 3 -LogFile $LogFile}
    }

Function Restart-ComputerCMClient {
    $time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue
    $CcmRestart = Start-Process -FilePath c:\windows\ccm\CcmRestart.exe -PassThru -Wait -WindowStyle Hidden
    }

#Not used, but here for reference
Function TriggerAppEval
    {
    #Includes 2 Methods, but both only seem to trigger Machine Evals, was unable to get it to trigger User App Eval
    #Method 1
    [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000121}') #App Eval
    #Method 2
    $SCCMClient = New-Object -COM 'CPApplet.CPAppletMgr'
    ($SCCMClient.GetClientActions() | Where-Object {$_.Name -match "Application"}).PerformAction()
    }

if ($Method -eq "Install")
    {
    if (!(Test-Path $RegistryPath)){New-Item -Path $RegistryPath}
    #Set the Registry Key, used for Detection
    Set-ItemProperty -Path $RegistryPath -Name "FakeApp" -Value "True" -Force
    CMTraceLog -Message "Set $RegistryPath Property FakeApp to True" -Type 1 -LogFile $LogFile
    CMTraceLog -Message "Exit Script with code: $ExitCode" -Type 1 -LogFile $LogFile
    if ($ExitCode -eq 3010 -or $ExitCode -eq 1641)
        {
        #TriggerRebootProgram - Not using anymore
        Restart-ComputerCMClient
        }
    ExitWithCode -exitcode $ExitCode #Triggers Restart Dialog and sets the Software Center Status to "Restart"
    }


if ($Method -eq "Uninstall")
    {
    #Switch the Value to False to make the detection think the "App" is not installed.
    Set-ItemProperty -Path $RegistryPath -Name "FakeApp" -Value "False" -Force
    CMTraceLog -Message "Set $RegistryPath Property FakeApp to False" -Type 1 -LogFile $LogFile

    #ClearDeadline #No longer used, this Idea did not pan out
    }
