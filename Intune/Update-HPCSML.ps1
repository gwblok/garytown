<# Gary Blok | @gwblok | GARYTOWN.COM | RecastSoftware.com

Installs or Updated HPCMSL: https://developers.hp.com/hp-client-management/doc/client-management-script-library

Checks latest version of HPCMSL available from HP.com and compares against machine it's running on.
Checks if it has HPCMSL installed via EXE installer, or via PowerShell Gallery.
If via EXE, then it downloads the EXE installer from HP and installs
If via Gallery, then runs "Install-Module" to update it

Can be used for both Discovery & Remediation, change $Remediation to $true to remediate.

TO DO: Add Logging leveraging CMTraceLog Function.

Created 2021.06.09 - Posted on GitHub - No testing has been done yet. :-) 
Changes
2021.06.10 - Updated Function that gets info from HP Website and merged it into 1
2021.06.10 - Added logic to "exit 1" if running in discovery mode & non-compliant to trigger remediation
2021.06.10 - Added URL that is bad, but it's nice as it grabs old version of the EXE (1.5.0) you can use to test updating 
#>

$Compliance = $true 

$ScriptName = "Update-HPCMSL"
$ScriptVersion = "21.6.14.1"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\$ScriptName.log"
$Remediate = $false
if ($Remediate -eq $true){$ComponentText = "Intune - Remediation"}
else {$ComponentText = "Intune - Detection"}

if (!(Test-Path -Path $LogFilePath)){$NewFolder = New-Item -Path $LogFilePath -ItemType Directory -Force}


# Resetting Vars during Testing
$InstalledHPCMSLModuleVer = $null
$InstalledHPCMSLInstallerVer  = $null
$InstallHPCMSLInstaller = $null
#$URL = https://ftp.hp.com/pub/caps-softpaq/cmit/release/cmsl/hp-cmsl-latest.exe # as of 2021.06.10 - This is a BAD link, grabs old version.


[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
		    [Parameter(Mandatory=$false)]
		    $Component = $ComponentText,
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Logs\IForgotToName.log"
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

function Get-HPCMSLWebInfo {
# HTML Scraping... this could break if HP changes their page layout.
Set-Location C:\
 
# Download html content file
$filepath = "$env:temp\Downloads.html"
 
#https://www8.hp.com/us/en/ads/clientmanagement/download.html
Invoke-WebRequest -Uri https://www8.hp.com/us/en/ads/clientmanagement/download.html -OutFile $filepath
 
# find all <td> tags and put into an array
$myarray = gc $filepath | 
    % { [regex]::matches( $_ , '(?<=<td>)(.*?)(?=</td>)' ) } | select -expa value
    # search for the CMSL tag and the next item is the version number
for ($i = 0 ; $i -lt $myarray.Count; $i++ ) {
    if ( $myarray[$i] -match 'script library' ) { 
        $CMSLversion = $myarray[$i+1] ; $CMSLURL = $myarray[$i+3]
        $CMSLURL = ($myarray[$i+3]).Split("`"")[1]
        break 
        }
}

$CMSLInfo = New-Object -TypeName PSObject
$Info = [ordered]@{Version="$CMSLversion";URL="$CMSLURL"}
$CMSLInfo | Add-Member -NotePropertyMembers $Info

$CMSLInfo

}

CMTraceLog -Message  "-------------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile

#Check for HP PS Module
Import-Module -Name "HPCMSL" -ErrorAction SilentlyContinue
$HPCMSL = Get-Module -Name "HPCMSL"
if ($HPCMSL){[Version]$InstalledHPCMSLModuleVer = $HPCMSL.Version}
Else{#Write-Output "No HPCMSL PS Module"
    }


#Check for HP Installer
$InstalledSoftwareRegistryX64 = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$InstalledSoftwareRegistryx86 = Get-ChildItem "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$InstalledSoftwareRegistry = $InstalledSoftwareRegistryX64 + $InstalledSoftwareRegistryx86
$InstalledSoftwareRegistryItems = @()
Foreach ($InstalledSoftware in $InstalledSoftwareRegistry)
    {
    if ($InstalledSoftware.GetValue('DisplayName') -eq "HP Client Management Script Library")
        {
        #Write-Output "Found $($InstalledSoftware.GetValue('DisplayName')) Version: $($InstalledSoftware.GetValue('DisplayVersion'))"
        $InstalledHPCMSLInstallerVer = $InstalledSoftware.GetValue('DisplayVersion')
        CMTraceLog -Message  "Found $($InstalledSoftware.GetValue('DisplayName')) Version: $($InstalledSoftware.GetValue('DisplayVersion'))" -Type 1 -LogFile $LogFile
        }
    else
        {
        #Write-Output "NOT $($InstalledSoftware.GetValue('DisplayName'))"
        #CMTraceLog -Message  "HPCMSL Installer Not Found" -Type 1 -LogFile $LogFile
        }
    }


$CurrentHPVer = (Get-HPCMSLWebInfo).Version
#IF Module installed via Installer, Update Via Installer
if ($InstalledHPCMSLInstallerVer -and $InstalledHPCMSLModuleVer)
    {
    #Write-Output "Has Installer"
    if ($InstalledHPCMSLInstallerVer -eq $CurrentHPVer)
        {
        CMTraceLog -Message  "HPCMSL Current" -Type 1 -LogFile $LogFile
        #Write-Output "HPCMSL Current"
        #Write-Output "Compliant"
        exit 0
        }
    else
        {
        $InstallHPCMSLInstaller = $True
        CMTraceLog -Message  "New HPCMSL found online: $CurrentHPVer" -Type 2 -LogFile $LogFile
        }
    }
#IF Module is installed via PowerShell Gallery, Update it via PowerShell Gallery
elseif (-not $InstalledHPCMSLInstallerVer -and $InstalledHPCMSLModuleVer)
    {
    Write-Output "Has PS Module (No Installer)"
    CMTraceLog -Message  "Has PS Module (No Installer)" -Type 1 -LogFile $LogFile
    if ($InstalledHPCMSLModuleVer -eq $CurrentHPVer)
        {
        #Write-Output "HPCMSL Current"
        #Write-Output "Compliant"
        CMTraceLog -Message  "HPCMSL Current" -Type 1 -LogFile $LogFile
        exit 0
        }
    else
        {
        if ($Remediate -eq $true){
            CMTraceLog -Message  "Remediating... (Install-Module -Name HPCMSL -Force -AcceptLicense)" -Type 2 -LogFile $LogFile
            Install-Module -Name HPCMSL -Force -AcceptLicense
            exit 0
            }
        else{
            #Write-Output "Non-Compliant"
            CMTraceLog -Message  "New HPCMSL found online: $CurrentHPVer" -Type 2 -LogFile $LogFile
            $Compliance = $false
            exit 1 
            }
        }
    }
#If No Module or Installer, install via Installer
else
    {
    #Write-Output "No HPCMSL"
    #Write-Output "Non-Compliant"
    CMTraceLog -Message  "HPCMSL Not on this System" -Type 2 -LogFile $LogFile
    $Compliance = $false
    $InstallHPCMSLInstaller = $True
    if ($Remediate -eq $false){exit 1}
    }

if ($Remediate -eq $true)
    {
    CMTraceLog -Message  "Remeditating... " -Type 1 -LogFile $LogFile
    if ($InstallHPCMSLInstaller){
        $WorkingDir = "$env:TEMP\HP"
        if (Test-Path -Path $WorkingDir){Remove-Item -Path $WorkingDir -Recurse -Force}
        $Null = New-Item -Path $WorkingDir -ItemType Directory -Force
        $DownloadURL = (Get-HPCMSLWebInfo).URL
        CMTraceLog -Message  "Downloading $DownloadURL ... " -Type 1 -LogFile $LogFile
        $FileName = $DownloadURL.Split("/") | Select-Object -Last 1
        $Download = Invoke-WebRequest -Uri $DownloadURL -UseBasicParsing -OutFile "$WorkingDir\$Filename" -PassThru
        if (Test-Path -Path "$WorkingDir\$Filename"){
            $InstallProcess = Start-Process -FilePath "$WorkingDir\$Filename" -ArgumentList "/VERYSILENT /LOG=$($WorkingDir)\$($Filename).log" -Wait -PassThru
            CMTraceLog -Message  "Install Complete with Exit Code $InstallProcess.exitcode" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "Log File: $($WorkingDir)\$($Filename).log" -Type 1 -LogFile $LogFile
            exit 0
            }
        else {
            Write-Output "Failed to download."
            CMTraceLog -Message  "Failed to Download" -Type 1 -LogFile $LogFile
            $Compliance = $false
            }
        }
    }
else
    {
    if (!($InstallHPCMSLInstaller)){$Compliance = $false} #NonCompliant on Detection Script
    }

if ($Compliance -eq $false){exit 1}
if ($Compliance -eq $true){exit 0}
