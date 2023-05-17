<#
.SYNOPSIS
    Installs Bing Wallpaper app... because I like it.
.DESCRIPTION
    Checks for Bing Wallpaper Process, if not found, marked non-compliant... if non-compliant, remediation will download and install
    
    Detection & Remediation = Same Script.  Change $Remediate = $true to $false for Detection Script
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by @gwblok
.LINK
    https://garytown.com
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

$ScriptVersion = "22.12.30.1"
$ScriptName = "Install Bing Wallpaper"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\BingWallpaper.log"

if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}
$Remediate = $false

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

CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile
if ($Remediate)
    {
    CMTraceLog -Message  "Running Script in Remediation Mode" -Type 1 -LogFile $LogFile
    $Process = Get-Process -Name BingWallpaperApp -ErrorAction SilentlyContinue
    if ($Process){
        CMTraceLog -Message "Bing Wallpaper App Already Installed, Exiting" -Type 1 -LogFile $LogFile
    }
    else{
        CMTraceLog -Message "Bing Wallpaper not found to be running, starting install process" -Type 1 -LogFile $LogFile
        $BingURL = "https://go.microsoft.com/fwlink/?linkid=2126594"
        $BingEXE =  "$env:TEMP\BW.exe"
        $BingWorking = "$env:TEMP\BW"

        if (!(Test-Path -Path $BingEXE)){
            CMTraceLog -Message "Downloading Bing Wallpaper Installer...." -Type 1 -LogFile $LogFile            
            Invoke-WebRequest -UseBasicParsing -Uri $BingURL -OutFile $BingEXE
        }
        if (Test-Path -Path $BingWorking){
            Remove-Item -Path $BingWorking -Force -Recurse | Out-Null
        }

        if (Test-Path -Path $BingEXE){
    
            $Expand = Start-Process -FilePath $BingEXE -ArgumentList "/C /T:$BingWorking" -Wait -PassThru
            if (Test-Path -Path "$BingWorking\BWCInstaller.msi"){
                CMTraceLog -Message "Successfully Extracted $BingEXE" -Type 1 -LogFile $LogFile
                CMTraceLog -Message "Starting Installation" -Type 1 -LogFile $LogFile
                $Install = Start-Process -FilePath "$BingWorking\BWCInstaller.msi" -ArgumentList "/qn ALLUSERS=1" -Wait -PassThru
        
            }
            else{
                CMTraceLog -Message "Failed to Extract $BingExe" -Type 1 -LogFile $LogFile
            }
        }
        Start-Sleep -Seconds 5
        $Process = Get-Process -Name BingWallpaperApp -ErrorAction SilentlyContinue
        if ($Process){
            CMTraceLog -Message "Bing Wallpaper App is now active" -Type 1 -LogFile $LogFile
        }
    }
}
else
    {
    CMTraceLog -Message  "Running Script in Detection Mode" -Type 1 -LogFile $LogFile
    $Process = Get-Process -Name BingWallpaperApp -ErrorAction SilentlyContinue
    if ($Process){
        CMTraceLog -Message "Bing Wallpaper App Already Installed, Exit 0" -Type 1 -LogFile $LogFile
    }
    else{
        CMTraceLog -Message "Bing Wallpaper Requires Installation, Exit 1" -Type 1 -LogFile $LogFile
        exit 1
    }
}
