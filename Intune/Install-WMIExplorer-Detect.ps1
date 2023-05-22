<#
Gary Blok - @gwblok - GARYTOWN.COM
.Synopsis
  Proactive Remediation for WMIExplorer to be on endpoint

 .Description
  Downloads WMIExplorer from GitHub, Copies to System32 if it's not already there
#>
$AppName = "WMIExplorer"
$FileName = "WMIExplorer.zip"
$ExpandPath = "$env:windir\system32"
$URL = "https://github.com/vinaypamnani/wmie2/releases/download/v2.0.0.2/WmiExplorer_2.0.0.2.zip"
$AppPath = "$ExpandPath\WMIExplorer.exe"


if (!(Test-Path -Path $AppPath)){
    Write-Output "$AppName Not Found, Exit 1"
    exit 1
}
else {
    Write-Output "$AppName Already Installed"
}
