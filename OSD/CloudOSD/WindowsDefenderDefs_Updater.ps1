

<#################################################################################

Script name: WindowsDefenderDefs_Updater.ps1
Orignal Author: Johan Schrewelius, Onevinn AB

Modified by Gary Blok, Recast Software for OSD 
Updated 2022.02.22
 - Added Cmtrace Log function and logging
 - Removed x86 Support
 - Added Defender Platform Updates (Thanks to MS just recently making a static URL to download them.)
 - Disabled NIS Download, which hasn't updated in forever anyway, and I'm pretty sure the MPAM defs cover the NIS stuff too.
 

##################################################################################>

#region: CMTraceLog Function formats logging in CMTrace style
Function Write-CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "OSDCloud",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile = "$LogFolder\OSDCloud.log"
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

# Configuration ##################################################################

try {
$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
$SMSTSLogsPath = $tsenv.value('_SMSTSLogPath')
$LogFolder = $tsenv.value('LogFolder')
if (!($LogFolder)){$LogFolder = $SMSTSLogsPath}
    }
catch{
Write-Output "Not in TS"
if (!($LogFolder)){$LogFolder = "$env:ProgramData\OSD\Logs"}
    }
if (!(Test-Path -path $LogFolder)){$Null = new-item -Path $LogFolder -ItemType Directory -Force}


#$Destination = "D:\PkgSource\Defender Definitions" #This will be grabbed from the Package Source Info


$ScriptVer = "2022.02.22.1"
$Component = "WinDefenderDefs"
$LogFile = "$LogFolder\MSDefenderUpdater.log"

# Source Addresses - Defender for Windows 10, 8.1 ################################

#$sourceAVx86 = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x86"
#$sourceNISx86 = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x86&nri=true"
#$sourcePlatformx86 = "https://go.microsoft.com/fwlink/?LinkID=870379&clcid=0x409&arch=x86"
$sourceAVx64 = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
$sourceNISx64 = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x64&nri=true"
$sourcePlatformx64 = "https://go.microsoft.com/fwlink/?LinkID=870379&clcid=0x409&arch=x64"

# Web client #####################################################################


Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "UPDATE Defender: Script version $ScriptVer..." -Type 1
Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "Running Script as $env:USERNAME" -Type 1
Write-Output "UPDATE Defender Package Script version $ScriptVer..."
# Prepare Intermediate folder ###################################################

$Intermediate = "$env:TEMP\DefenderScratchSpace"

if(!(Test-Path -Path "$Intermediate")) {
    $Null = New-Item -Path "$env:TEMP" -Name "DefenderScratchSpace" -ItemType Directory
}

if(!(Test-Path -Path "$Intermediate\x64")) {
    $Null = New-Item -Path "$Intermediate" -Name "x64" -ItemType Directory
}

Remove-Item -Path "$Intermediate\x64\*" -Force -EA SilentlyContinue

$wc = New-Object System.Net.WebClient


# x64 AV #########################################################################

$Dest = "$Intermediate\x64\" + 'mpam-fe.exe'
Write-Output "Starting MPAM-FE Download"
Write-CMTraceLog -Message "Starting MPAM-FE Download" -Type 1

$wc.DownloadFile($sourceAVx64, $Dest)

if(Test-Path -Path $Dest) {
    $x = Get-Item -Path $Dest
    [version]$Version1a = $x.VersionInfo.ProductVersion #Downloaded
    [version]$Version1b = (Get-MpComputerStatus).AntivirusSignatureVersion #Currently Installed

    if ($Version1a -gt $Version1b){
        Write-Output "Starting MPAM-FE Install of $Version1b to $Version1a"
        Write-CMTraceLog -Message "Starting MPAM-FE Install of $Version1b to $Version1a" -Type 1
        $MPAMInstall = Start-Process -FilePath $Dest -Wait -PassThru
        }
    else
        {
        Write-Output "No Update Needed, Installed:$Version1b vs Downloaded: $Version1a"
        Write-CMTraceLog -Message "No Update Needed, Installed:$Version1b vs Downloaded: $Version1a" -Type 1
        }

    Write-Output "Finished MPAM-FE Install"
    Write-CMTraceLog -Message "Finished MPAM-FE Install" -Type 1
}
else
    {
    Write-Output "Failed MPAM-FE Download"
    Write-CMTraceLog -Message "Failed MPAM-FE Download" -Type 1
    }

# x64 Update Platform ########################################################################
Write-Output "Starting Update Platform Download"
Write-CMTraceLog -Message "Starting Update Platform Download" -Type 1
$Dest = "$Intermediate\x64\" + 'UpdatePlatform.exe'
$wc.DownloadFile($sourcePlatformx64, $Dest)

if(Test-Path -Path $Dest) {
    


    $x = Get-Item -Path $Dest
    [version]$Version2a = $x.VersionInfo.ProductVersion #Downloaded
    [version]$Version2b = (Get-MpComputerStatus).AMServiceVersion #Installed

    if ($Version2a -gt $Version2b){
        Write-Output "Starting Update Platform Install of $Version2b to $Version2a"
        Write-CMTraceLog -Message "Starting Update Platform Install of $Version2b to $Version2a" -Type 1
        $UPInstall = Start-Process -FilePath $Dest -Wait -PassThru
        }
    else
        {
        Write-Output "No Update Needed, Installed:$Version2b vs Downloaded: $Version2a"
        Write-CMTraceLog -Message "No Update Needed, Installed:$Version2b vs Downloaded: $Version2a" -Type 1
        }

    Write-Output "Finished Update Platform Install"
    Write-CMTraceLog -Message "Finished Update Platform Install" -Type 1
}
else
    {
    Write-Output "Failed Update Platform Download"
    Write-CMTraceLog -Message "Failed Update Platform Download" -Type 1
    }

# x64 Update Platform #########################################################################

Write-CMTraceLog -Message "=====================================================" -Type 1
