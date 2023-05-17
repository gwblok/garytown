<#Sysinternals Suite Installer
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

Downloads the Sysinternal Suite directly from Microsoft
Expands to ProgramFiles\SysInternalsSuite & Adds to Path

Creates shortcut in Start Menu for the items in $Shortcuts Variable
Shortcut Variable based on $_.VersionInfo.InternalName of the exe file for the one you want a shortcut of.


#>

try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}

$ScriptName = "Sysinternals-Suite"

$ScriptVersion = "22.03.07.01"
if ($tsenv){
    $LogFolder = $tsenv.value('CompanyFolder')#Company Folder is set during the TS Var at start of TS.
    $CompanyName = $tsenv.value('CompanyName')
    }
if (!($CompanyName)){$CompanyName = "RecastSoftwareIT"}#If CompanyName / CompanyFolder info not found in TS Var, use this.
if (!($LogFolder)){$LogFolder = "$env:ProgramData\$CompanyName"}
$LogFilePath = "$LogFolder\Logs"
$LogFile = "$LogFilePath\Sysinternals-Suite.log"

#Create Shortcuts for:
$ShortCuts = @("Process Explorer", "Process Monitor", "RDCMan.exe", "ZoomIt")

#Download & Extract to Program Files
$FileName = "SysinternalsSuite.zip"
$InstallPath = "$env:ProgramFiles\SysInternalsSuite\"
$ExpandPath = "$env:TEMP\SysInternalsSuiteExpanded"


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

$URL = "https://download.sysinternals.com/files/$FileName"
$DownloadTempFile = "$env:TEMP\$FileName"

CMTraceLog -Message  "Downloading $URL to $DownloadTempFile" -Type 1 -LogFile $LogFile
$Download = Start-BitsTransfer -Source $URL -Destination $DownloadTempFile -DisplayName $FileName



#Write-Output "Downloaded Version Newer than Installed Version, overwriting Installed Version"
CMTraceLog -Message  "Downloaded Version Newer than Installed Version, overwriting Installed Version" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Expanding to $InstallPath" -Type 1 -LogFile $LogFile
Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $InstallPath -Force

#ShortCut Folder
if (!(Test-Path -path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SysInternals")){$NULL = New-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SysInternals" -ItemType Directory}

$Sysinternals = get-childitem -Path $InstallPath
foreach ($App in $Sysinternals)#{}
    {
            $AppInternalName = $App.VersionInfo.InternalName
            $AppName = $App.VersionInfo.ProductName
            $AppFileName = $App.Name
            if ($AppInternalName -in $ShortCuts)
                {
                #Write-Output $AppName
                #Write-Output $AppInternalName
                #Write-Output $AppFileName
                if ($App.Name -match "64")
                    {
                    if ($AppName -match "Sysinternals"){
                        $AppName = $AppName.Replace("Sysinternals ","")
                        }
                    CMTraceLog -Message  "Create Shortcut for $($App.Name)" -Type 1 -LogFile $LogFile
                    #Write-Host "Create Shortcut for $($App.Name)" -ForegroundColor Green
                    #Build ShortCut Information
                    $SourceExe = $App.FullName
                    $ArgumentsToSourceExe = "/AcceptEULA"
                    $DestinationPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SysInternals\$($AppName).lnk"

                    #Create Shortcut
                    $WshShell = New-Object -comObject WScript.Shell
                    $Shortcut = $WshShell.CreateShortcut($DestinationPath)
                    $Shortcut.TargetPath = $SourceExe
                    $Shortcut.Arguments = $ArgumentsToSourceExe
                    $Shortcut.Save()
                    }
                else
                    {
                    $64BigVersion = $Sysinternals | Where-Object {$_.Name -match "64" -and $_.VersionInfo.ProductName -match $AppName}
                    if ($64BigVersion){
                        #Write-Output "Found 64Bit Version: $($64BigVersion.Name), Using that instead"
                        }
                    else {
                        if ($AppName -match "Sysinternals"){
                            $AppName = $AppName.Replace("Sysinternals ","")
                            }
                        #Write-Output "No 64Bit Version, use 32bit"
                        #Write-Host "Create Shortcut for $($App.Name)" -ForegroundColor Green
                        CMTraceLog -Message  "Create Shortcut for $($App.Name)" -Type 1 -LogFile $LogFile
                        #Build ShortCut Information
                        $SourceExe = $App.FullName
                        $ArgumentsToSourceExe = "/AcceptEULA"
                        $DestinationPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\SysInternals\$($AppName).lnk"
                        #Create Shortcut
                        $WshShell = New-Object -comObject WScript.Shell
                        $Shortcut = $WshShell.CreateShortcut($DestinationPath)
                        $Shortcut.TargetPath = $SourceExe
                        $Shortcut.Arguments = $ArgumentsToSourceExe
                        $Shortcut.Save()
                
                        }
                    }
                }
            }

#Add ProgramFiles\SysInternalsSuite to Path

#Get Current Path
$Environment = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$newpath = $Environment.Split(";")
if (!($newpath -contains "$InstallPath")){
            CMTraceLog -Message  "Adding $InstallPath to Path Variable" -Type 1 -LogFile $LogFile
            [System.Collections.ArrayList]$AddNewPathList = $newpath
            $AddNewPathList.Add("$InstallPath")
            $FinalPath = $AddNewPathList -join ";"

            #Set Updated Path
            [System.Environment]::SetEnvironmentVariable("Path", $FinalPath, "Machine")
            }
else
    {
            CMTraceLog -Message  "$InstallPath already in Path Variable" -Type 1 -LogFile $LogFile
            }





CMTraceLog -Message  "--------------------------------------------------------" -Type 1 -LogFile $LogFile
