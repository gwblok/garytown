<#
.SYNOPSIS
    Enables Transcription
.DESCRIPTION 
    This will Enable PowerShell Script Transcription
    Logs items to $LogPath
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by @gwblok
.LINK
    https://garytown.com
.LINK
    https://www.recastsoftware.com
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

$ScriptVersion = "21.3.25.1"
$whoami = (whoami).split("\") | Select-Object -Last 1
$RootLoggingPath = "$env:ProgramData\CustomLogging"
$LogFile = "$RootLoggingPath\PSTranscriptionLoggingEnable.log"
$Component = "Intune"
$PSTranscriptsFolder = "$RootLoggingPath\PSTranscripts"
if (!(Test-Path -Path $RootLoggingPath)){$NewFolder = New-Item -Path $RootLoggingPath -ItemType Directory -Force}
$Mode = "Enable"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
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

#https://adamtheautomator.com/powershell-logging-recording-and-auditing-all-the-things/
#useful when Troubleshooting the PowerShell Scripts
function Set-PSTranscriptionLogging {
	param(
		[Parameter(Mandatory)]
		[string]$OutputDirectory,
        [Parameter(Mandatory)]		
        [ValidateNotNullOrEmpty()][ValidateSet("Enable", "Disable")][string]$Mode
	)

     # Registry path
     $basePath = 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\PowerShell\Transcription'

     # Create the key if it does not exist
     if ($Mode -eq "Enable")
        {
         if(-not (Test-Path $basePath))
         {
             $null = New-Item $basePath -Force -ErrorAction SilentlyContinue

             # Create the correct properties
             New-ItemProperty $basePath -Name "EnableInvocationHeader" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "EnableTranscripting" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "OutputDirectory" -PropertyType String -ErrorAction SilentlyContinue
         }

         # These can be enabled (1) or disabled (0) by changing the value
         Set-ItemProperty $basePath -Name "EnableInvocationHeader" -Value "1" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "EnableTranscripting" -Value "1" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "OutputDirectory" -Value $OutputDirectory -Force -ErrorAction SilentlyContinue
         }
    elseif ($Mode -eq "Disable")
        {
        if(-not (Test-Path $basePath))
            {
             $null = New-Item $basePath -Force -ErrorAction SilentlyContinue

             # Create the correct properties
             New-ItemProperty $basePath -Name "EnableInvocationHeader" -PropertyType Dword -ErrorAction SilentlyContinue
             New-ItemProperty $basePath -Name "EnableTranscripting" -PropertyType Dword -ErrorAction SilentlyContinue
            }

        # These can be enabled (1) or disabled (0) by changing the value
         Set-ItemProperty $basePath -Name "EnableInvocationHeader" -Value "0" -Force -ErrorAction SilentlyContinue
         Set-ItemProperty $basePath -Name "EnableTranscripting" -Value "0" -Force -ErrorAction SilentlyContinue

        }

}

function Get-PSTranscriptionLogging {

     # Registry path
     $basePath = 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\PowerShell\Transcription'

     if(-not (Test-Path $basePath))
        {
        Return "Disabled"
        }
     else
        {
        $EnableInvocationHeader = Get-ItemPropertyValue -Path $basePath -Name EnableInvocationHeader -ErrorAction SilentlyContinue
        $EnableTranscripting = Get-ItemPropertyValue -Path $basePath -Name "EnableTranscripting" -ErrorAction SilentlyContinue
        $OutputDirectory = Get-ItemPropertyValue -Path $basePath -Name "OutputDirectory" -ErrorAction SilentlyContinue
        }
    if ($OutputDirectory -ne $PSTranscriptsFolder)
        {
        Return "WrongPath"
        }
    if ($EnableInvocationHeader -eq "1")
        {
        Return "Enabled"
        }
    if ($EnableTranscripting -eq "1")
        {
        Return "Enabled"
        }

}

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

CMTraceLog -Message  "---------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting PSTranscription Logging $Mode Script" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as $whoami" -Type 1 -LogFile $LogFile

CMTraceLog -Message  "Checking PowerShell Transcription Status" -Type 1 -LogFile $LogFile
$PSTranscriptionStatus = Get-PSTranscriptionLogging

if ($PSTranscriptionStatus -eq "Disabled")
    {
    CMTraceLog -Message  "PowerShell Transcription is Disabled Currently" -Type 1 -LogFile $LogFile
    CMTraceLog -Message  "Enabling PowerShell Transcription" -Type 1 -LogFile $LogFile
    if (!(Test-Path $PSTranscriptsFolder))
        {
        CMTraceLog -Message  "Creating Transcriptions Log Folder: $PSTranscriptsFolder" -Type 1 -LogFile $LogFile
        $NewFolder = new-item -Path $PSTranscriptsFolder -ItemType Directory -Force
        }
    Set-PSTranscriptionLogging -OutputDirectory $PSTranscriptsFolder -Mode $Mode
    CMTraceLog -Message  "Set PSTranscription to $Mode" -Type 1 -LogFile $LogFile
    }
Elseif ($PSTranscriptionStatus -eq "WrongPath")
    {
    CMTraceLog -Message  "PowerShell Transcription is Enabled But set to different Logging Folder" -Type 1 -LogFile $LogFile
    CMTraceLog -Message  "Updating Logging Path from $(Get-ItemPropertyValue -Path $basePath -Name "OutputDirectory") to $PSTranscriptsFolder" -Type 1 -LogFile $LogFile
    if (!(Test-Path $PSTranscriptsFolder))
        {
        CMTraceLog -Message  "Creating Transcriptions Log Folder: $PSTranscriptsFolder" -Type 1 -LogFile $LogFile
        $NewFolder = new-item -Path $PSTranscriptsFolder -ItemType Directory -Force
        }
    Set-PSTranscriptionLogging -OutputDirectory $PSTranscriptsFolder -Mode $Mode
    CMTraceLog -Message  "Updated Logging Path" -Type 1 -LogFile $LogFile
    }

Else
    {
    CMTraceLog -Message  "PowerShell Transcription is already Enabled, Exiting" -Type 1 -LogFile $LogFile
    }


CMTraceLog -Message  "Complete PSTranscription Logging $Mode Script" -Type 1 -LogFile $LogFile


exit $exitcode
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
