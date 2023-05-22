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
    Write-Output "$AppName Not Found, Starting Remediation"
    #Download & Extract to System32
  Write-Output "Downloading $URL"
  Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
  if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
  else{Write-Output "Failed Downloaded"; exit 255}
  Write-Output "Starting Extraction of $AppName to $ExpandPath"
  Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
  if (Test-Path -Path $AppPath){Write-Output "Successfully Extracted Zip File"}
  else{Write-Output "Failed Extract"; exit 255}
}
else {
    Write-Output "$AppName Already Installed"
}





$FileName = "WMIExplorer.zip"
$ExpandPath = "$env:windir\system32"
$URL = "https://github.com/vinaypamnani/wmie2/releases/download/v2.0.0.2/WmiExplorer_2.0.0.2.zip"

$WMIExplorerPath = "$ExpandPath\WMIExplorer.exe"
if (!(Test-Path -Path $WMIExplorerPath)){
    Write-Output "WMI Explorer Not Found, Starting Remediation"
    #Download & Extract to System32
  Write-Output "Downloading $URL"
  Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
  if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
  else{Write-Output "Failed Downloaded"; exit 255}
  Write-Output "Starting Extraction of SDelete64 to $ExpandPath"
  Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
  if (Test-Path -Path $WMIExplorerPath){Write-Output "Successfully Extracted Zip File"}
  else{Write-Output "Failed Extract"; exit 255}
}
else {
    Write-Output "WMI Explorer Already Installed"
}



