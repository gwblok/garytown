<#LAPS Client x64 Install from Internet
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

#>

try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}

$ScriptName = "LAPS Client Installer"

$ScriptVersion = "22.03.16.01"
if ($tsenv){
    $LogFolder = $tsenv.value('CompanyFolder')#Company Folder is set during the TS Var at start of TS.
    $CompanyName = $tsenv.value('CompanyName')
    }
if (!($CompanyName)){$CompanyName = "RecastSoftwareIT"}#If CompanyName / CompanyFolder info not found in TS Var, use this.
if (!($LogFolder)){$LogFolder = "$env:ProgramData\$CompanyName"}
$LogFilePath = "$LogFolder\Logs"
$LogFile = "$LogFilePath\WMIExplorer.log"

#Download & Extract to Program Files
$FileName = "LAPS.x64.msi"
$URL = "https://download.microsoft.com/download/C/7/A/C7AAD914-A8A6-4904-88A1-29E657445D03/$FileName"
$DownloadTempFile = "$env:TEMP\$FileName"

<# From: https://www.ephingadmin.com/powershell-cmtrace-log-function/
$LogFilePath = "$env:TEMP\Logs"
$LogFile = "$LogFilePath\SetComputerName.log"
CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile

#>
function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
		    [Parameter(Mandatory=$false)]
		    $Component = "$ComponentText",
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

if (!(Test-Path -Path $LogFilePath)){$Null = New-Item -Path $LogFilePath -ItemType Directory -Force}

CMTraceLog -Message  "Running Script: $ScriptName | Version: $ScriptVersion" -Type 1 -LogFile $LogFile
Write-Output "Running Script: $ScriptName | Version: $ScriptVersion"

$TestURL = $Null

try {
    $TestURL = Invoke-WebRequest -Uri $URL -DisableKeepAlive -UseBasicParsing -Method head -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
    }
catch{}
if ($TestURL.BaseResponse){
    CMTraceLog -Message  "Successful Test of LAPS Download URL: $URL" -Type 1 -LogFile $LogFile
    Write-Output "Successful Test of LAPS Download URL: $URL"
    }
else {
    CMTraceLog -Message  "Failed Test of LAPS Download URL: $URL" -Type 1 -LogFile $LogFile
    Write-Output "Failed Test of LAPS Download URL: $URL"
    exit 253
    }

CMTraceLog -Message  "Downloading $URL to $DownloadTempFile" -Type 1 -LogFile $LogFile
Write-Output "Downloading $URL to $DownloadTempFile"
$Download = Start-BitsTransfer -Source $URL -Destination $DownloadTempFile -DisplayName $FileName
if (Test-Path -Path $DownloadTempFile){
    CMTraceLog -Message  "Successfully Downloaded $FileName" -Type 1 -LogFile $LogFile
    Write-Output "Successfully Downloaded $FileName"
    }
else{
    CMTraceLog -Message "Failed to Downloaded $FileName" -Type 1 -LogFile $LogFile
    Write-Output "Failed to Downloaded $FileName"
    exit 253    
    }

#Write-Output "Downloaded Version Newer than Installed Version, overwriting Installed Version"
CMTraceLog -Message  "Installing $FileName" -Type 1 -LogFile $LogFile
Write-Output "Installing $FileName"
$Install = Start-Process -FilePath "$DownloadTempFile" -ArgumentList "/qb!" -PassThru -Wait
if ($Install.ExitCode -eq 0){
    CMTraceLog -Message  "Installation Exit Successfully" -Type 1 -LogFile $LogFile
    Write-Output "Installation Exit Successfully"
    }


CMTraceLog -Message  "--------------------------------------------------------" -Type 1 -LogFile $LogFile
