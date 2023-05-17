<#WMI Explorer
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

Downloads the WMIExplorer Suite directly from GitHub

Creates shortcut in Start Menu for the items in $Shortcuts Variable
Shortcut Variable based on $_.VersionInfo.InternalName of the exe file for the one you want a shortcut of.

#>

try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}

$ScriptName = "WMIExplorer"

$ScriptVersion = "22.03.07.01"
if ($tsenv){
    $LogFolder = $tsenv.value('CompanyFolder')#Company Folder is set during the TS Var at start of TS.
    $CompanyName = $tsenv.value('CompanyName')
    }
if (!($CompanyName)){$CompanyName = "RecastSoftwareIT"}#If CompanyName / CompanyFolder info not found in TS Var, use this.
if (!($LogFolder)){$LogFolder = "$env:ProgramData\$CompanyName"}
$LogFilePath = "$LogFolder\Logs"
$LogFile = "$LogFilePath\WMIExplorer.log"

#Download & Extract to Program Files
$FileName = "WmiExplorer_2.0.0.2.zip"
$InstallPath = "$env:windir\System32"


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

$URL = "https://github.com/vinaypamnani/wmie2/releases/download/v2.0.0.2/$FileName"
$DownloadTempFile = "$env:TEMP\$FileName"

CMTraceLog -Message  "Downloading $URL to $DownloadTempFile" -Type 1 -LogFile $LogFile
$Download = Start-BitsTransfer -Source $URL -Destination $DownloadTempFile -DisplayName $FileName

#Write-Output "Downloaded Version Newer than Installed Version, overwriting Installed Version"
CMTraceLog -Message  "Expanding to $InstallPath" -Type 1 -LogFile $LogFile
Expand-Archive -Path "$env:TEMP\$FileName" -DestinationPath $InstallPath -Force


$App = get-item -Path "$InstallPath\WmiExplorer.exe"

CMTraceLog -Message  "Create Shortcut for $($App.Name)" -Type 1 -LogFile $LogFile
#Write-Host "Create Shortcut for $($App.Name)" -ForegroundColor Green
#Build ShortCut Information
$AppName = $App.VersionInfo.ProductName
$SourceExe = $App.FullName
$DestinationPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\$($AppName).lnk"

#Create Shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()
                    

CMTraceLog -Message  "--------------------------------------------------------" -Type 1 -LogFile $LogFile
