

<#################################################################################

Script name: WindowsDefenderDefs_PackageUpdater.ps1
Usage: Run daily as Scheduled Task (gSMA Account)
Command: powershell.exe -NoProfile -ExecutionPolicy ByPass -File DownloadDefenderDefinitions.ps1
Author: Johan Schrewelius, Onevinn AB
Date: 2016-01-12 (1.0)
Updated 2016-01-24 (1.1): Author added mail functionality
Updated 2018-04-09 (1.2): Author added intermidiate download folder, existing definition files are not deleted in the event of failed download.

Acknowledgement: Andre Picker - https://gallery.technet.microsoft.com/scriptcenter/SCEP-Definition-Updates-to-fde57ebf

Modified by Gary Blok, Recast Software
Updated 2021.04.21
 - Modified to use native CM Commandlets
 - Added Cmtrace Log function and logging
 - Removed x86 Support
 - Changed $Destination to be populated by getting the package source location of $PackageID

 Updated 2021.10.12
 - Added Defender Platform Updates (Thanks to MS just recently making a static URL to download them.)
 - Disabled NIS Download, which hasn't updated in forever anyway, and I'm pretty sure the MPAM defs cover the NIS stuff too.
 

 $Destination = Package Share Destination folder 'Root folder'

 |- Root folder
    |- x86
    |- x64

 Remember to update:
 The Location in the Write-CMTraceLog Function
 $PackageID = PackageID for downloaded definition files (Root folder)
 $ProxyServer info
 
 $MailTo = List of Mail reciepients for notification
 $SentFrom = Mail Address of Sender, typícally Administrator
 $SmtpServer = FQDN of Smtp server

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
		    $Component = "SchTask",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile = "D:\ScheduledTaskScripts\MSDefenderUpdater.log"
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

#$Destination = "D:\PkgSource\Defender Definitions" #This will be grabbed from the Package Source Info
$ScriptVer = "2021.10.12.1"
$PackageID = "PS2009DC"
$MailTo = ""
$SentFrom = ""
$SmtpServer = ""



# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "cm.corp.viamonstra.com" # SMS Provider machine name

# Source Addresses - Defender for Windows 10, 8.1 ################################

#$sourceAVx86 = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x86"
#$sourceNISx86 = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x86&nri=true"
#$sourcePlatformx86 = "https://go.microsoft.com/fwlink/?LinkID=870379&clcid=0x409&arch=x86"
$sourceAVx64 = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
$sourceNISx64 = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x64&nri=true"
$sourcePlatformx64 = "https://go.microsoft.com/fwlink/?LinkID=870379&clcid=0x409&arch=x64"

# Web client #####################################################################


Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "UPDATE Defender Package Script version $ScriptVer..." -Type 1
Write-CMTraceLog -Message "=====================================================" -Type 1
Write-CMTraceLog -Message "Running Script as $env:USERNAME" -Type 1
Write-Output "UPDATE Defender Package Script version $ScriptVer..."
try {
# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
     Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
$GetModule = Get-Module ConfigurationManager
if(($GetModule) -eq $null) {
    Write-CMTraceLog -Message "Failed to Import ConfigMgr PowerShell Module" -Type 3
    }
else
    {
    Write-CMTraceLog -Message "ConfigMgr PowerShell Module Ver: $($GetModule.Version)" -Type 1
    }


# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
    }

if(($PSDrive = Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    Write-CMTraceLog -Message "Failed to create PSDrive to ConfigMgr" -Type 3
    }
else
    {
    Write-CMTraceLog -Message "CMSite Provider: $($PSDrive.Name) | $($PSDrive.Root) " -Type 1
    }

# Set the current location to be the site code.
Set-Location "$($SiteCode):\"

$CurrentLocation = Get-Location
if ($CurrentLocation -match $SiteCode)
    {
    Write-CMTraceLog -Message "Confirmed ConfigMgr Connection: $($CurrentLocation.ProviderPath)" -Type 1
    }
else
    {
    Write-CMTraceLog -Message "Current Path: $($CurrentLocation.ProviderPath)" -Type 1
    Write-CMTraceLog -Message "Failed to Connect to $SiteCode, exiting Script" -Type 3    
    Exit
    }
}

catch{
$CurrentLocation = Get-Location
Write-CMTraceLog -Message "Location: $($CurrentLocation.ProviderPath)" -Type 2
exit 2
}

# Get Package Information ######################################################
Set-Location "$($SiteCode):\"
$DefenderCMPackage = Get-CMPackage -Id $PackageID -Fast
$Destination = $DefenderCMPackage.PkgSourcePath
Set-Location "C:"

if (Test-Path $Destination)
    {
    "Testing Write Access with $($env:USERNAME)" | Out-File "$Destination\test.txt"
    if (Test-Path "$Destination\test.txt")
        {
        Write-CMTraceLog -Message "Confirmed Write Access to Package Source" -Type 1
        Remove-Item -Path "$Destination\test.txt" -Force
        }
    else
        {
         Write-CMTraceLog -Message "Failed Write Access to Package Source" -Type 3
         exit
        }
    }
else
    {
    Write-CMTraceLog -Message "Failed Connecting to Package Source" -Type 1
    Write-CMTraceLog -Message " Source Path:  $($DefenderCMPackage.PkgSourcePath)" -Type 1
    exit
    }
# Record Package Info
Write-CMTraceLog -Message "Package Info - Name: $($DefenderCMPackage.Name)" -Type 1
Write-CMTraceLog -Message " Source Path:  $($DefenderCMPackage.PkgSourcePath)" -Type 1
Write-CMTraceLog -Message " Source Version:  $($DefenderCMPackage.SourceVersion) (Before we update it below)" -Type 1
Write-CMTraceLog -Message " Source Last Refresh:  $($DefenderCMPackage.LastRefreshTime)" -Type 1

$ProxyServer = 'http://proxy.recastsoftware.com:8080'
$TestProxy = Test-NetConnection -ComputerName $ProxyServer -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

$wc = New-Object System.Net.WebClient

if ($TestProxy.PingSucceeded -eq $true){
    Write-Output "setting proxy to $ProxyServer"
    $wc.Proxy = [System.Net.WebRequest]::DefaultWebProxy = new-object system.net.webproxy($ProxyServer)
    $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    }


# Create MailTable
$table = New-Object system.Data.DataTable "MailTable"

# Define Columns
$col1 = New-Object system.Data.DataColumn File,([string])
$col2 = New-Object system.Data.DataColumn OldVersion,([string])
$col3 = New-Object system.Data.DataColumn NewVersion,([string])

# Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)

# Prepare Intermediate folder ###################################################

$Intermediate = "$env:TEMP\DefenderScratchSpace"

if(!(Test-Path -Path "$Intermediate")) {
    New-Item -Path "$env:TEMP" -Name "DefenderScratchSpace" -ItemType Directory
}

if(!(Test-Path -Path "$Intermediate\x64")) {
    New-Item -Path "$Intermediate" -Name "x64" -ItemType Directory
}

Remove-Item -Path "$Intermediate\x64\*" -Force -EA SilentlyContinue



# x64 AV #########################################################################

$Dest = "$Intermediate\x64\" + 'mpam-fe.exe'
$wc.DownloadFile($sourceAVx64, $Dest)

if(Test-Path -Path $Dest) {
    Write-Output "Starting MPAM-FE Download"
    $FinalDest = "$Destination\x64\" + 'mpam-fe.exe'

    if(Test-Path -Path $FinalDest) {
        $x = Get-Item -Path $FinalDest
        $v1a = $x.VersionInfo.ProductVersion
    }

    $x = Get-Item -Path $Dest
    $v2a = $x.VersionInfo.ProductVersion

    $row = $table.NewRow()
    $row.File = $Dest.Replace("$Destination\", "")
    $row.OldVersion = $v1a
    $row.NewVersion = $v2a
    $table.Rows.Add($row)

    Copy-Item -Path $Dest -Destination $FinalDest -Force -EA SilentlyContinue
    Write-Output "Finished MPAM-FE Download"
}

# x64 NIS ########################################################################
<#
$Dest = "$Intermediate\x64\" + 'nis_full.exe'
$wc.DownloadFile($sourceNISx64, $Dest)

if(Test-Path -Path $Dest) {

    $FinalDest = "$Destination\x64\" + 'nis_full.exe'

    if(Test-Path -Path $FinalDest) {
        $x = Get-Item -Path $FinalDest
        $v1b = $x.VersionInfo.ProductVersion
    }

    $x = Get-Item -Path $Dest
    $v2b = $x.VersionInfo.ProductVersion

    $row = $table.NewRow()
    $row.File = $Dest.Replace("$Destination\", "")
    $row.OldVersion = $v1b
    $row.NewVersion = $v2b
    $table.Rows.Add($row)

    Copy-Item -Path $Dest -Destination $FinalDest -Force -EA SilentlyContinue
}
#>
# x64 AV #########################################################################

$Dest = "$Intermediate\x64\" + 'UpdatePlatform.exe'
$wc.DownloadFile($sourcePlatformx64, $Dest)

if(Test-Path -Path $Dest) {
    Write-Output "Starting UpdatePlatform Download"
    $FinalDest = "$Destination\x64\" + 'UpdatePlatform.exe'

    if(Test-Path -Path $FinalDest) {
        $x = Get-Item -Path $FinalDest
        $v1c = $x.VersionInfo.ProductVersion
    }

    $x = Get-Item -Path $Dest
    $v2c = $x.VersionInfo.ProductVersion

    $row = $table.NewRow()
    $row.File = $Dest.Replace("$Destination\", "")
    $row.OldVersion = $v1c
    $row.NewVersion = $v2c
    $table.Rows.Add($row)

    Copy-Item -Path $Dest -Destination $FinalDest -Force -EA SilentlyContinue
    Write-Output "Finished UpdatePlatform Download"
}

# Update Content on DP ###########################################################
Set-Location "$($SiteCode):\"
Update-CMDistributionPoint -PackageId $PackageID
Set-CMPackage -id $PackageID -Version $v2a
#Set-CMPackage -id $PackageID -MifVersion $v2b
Set-CMPackage -id $PackageID -Language $v2c
Set-Location "C:"

Write-CMTraceLog -Message "mpam-fe.exe Updated from $v1a to $v2a " -Type 1
#Write-CMTraceLog -Message "nis_full.exe Updated from $v1b to $v2b " -Type 1
Write-CMTraceLog -Message "UpdatePlatform.exe Updated from $v1c to $v2c " -Type 1

Write-Output "mpam-fe.exe Updated from $v1a to $v2a "
Write-Output "UpdatePlatform.exe Updated from $v1c to $v2c "

# Send MailTO ####################################################################

if(![string]::IsNullOrEmpty($MailTo) -and ![string]::IsNullOrEmpty($SentFrom)) {

    $html = "<table cellspacing=`"10`"><tr><td>File</td><td>Old Version</td><td>New Version</td></tr>"

    foreach ($row in $table.Rows) { 
        $html += "<tr><td>" + $row[0] + "</td><td>" + $row[1] + "</td><td>" + $row[2] + "</td></tr>"
    }

    $html += "</table>"

    $dt = Get-Date
    $body = "Result of Defender Definitions download: " + $dt.ToString("yyyy-MM-dd HH:mm:ss") + "<br /><br /><br />" + $html

    Send-MailMessage -To $MailTo `
    -Subject "Status Defender Definitions Download" `
    -Body $body `
    -SmtpServer $SmtpServer `
    -From $SentFrom `
    -bodyashtml
}
