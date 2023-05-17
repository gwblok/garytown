<#
.SYNOPSIS
    Detection Script
    Installs Patch My PC Home app... and configures
.DESCRIPTION
    Checks for Patch My PC Home app in C:\ProgramFiles\PMPC and 'Installs' if not there.
    Adds Scheduled task to run daily
    Configures the App to install specific applications I like in my lab but creating the PMPC ini file.
    
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Script Created by @gwblok
    Home Updater by Patch My PC | Justin Chalfant | @SetupConfigMgr
.LINK
    https://garytown.com
    https://patchmypc.com/home-updater
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

$ScriptVersion = "22.12.30.1"
$ScriptName = "Install Patch My PC Home"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\PatchMyPCHome.log"
$URL = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
$ProgramFolder = "$env:ProgramFiles\PMPC"
$EXE =  "$env:ProgramFiles\PMPC\PatchMyPC.exe"
$TaskName = "PatchMyPC"
if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}


function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Intune",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Intune\Logs\IForgotToName.log"
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

CMTraceLog -Message  "-----------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile

$Tasks = Get-ScheduledTask | Where-Object {$_.TaskName -match $TaskName}
if ((Test-Path -Path $EXE) -and ($Tasks)){
    CMTraceLog -Message "Patch My PC Home App Already Installed, Exiting" -Type 1 -LogFile $LogFile -Component "Detection"
    }
else{
    CMTraceLog -Message "Patch My PC Home App Requires Installation, Exit 1" -Type 1 -LogFile $LogFile -Component "Detection"
    exit 1
}

