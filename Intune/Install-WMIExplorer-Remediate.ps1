

<#
Gary Blok - @gwblok - GARYTOWN.COM
.Synopsis
  Proactive Remediation for WMIExplorer to be on endpoint

 .Description
  Downloads WMIExplorer from GitHub, Copies to System32 if it's not already there
  Creates Generic Shortcut in Start Menu
#>


Function New-AppIcon {
    param(
    [string]$SourceExePath = "$env:windir\system32\control.exe",
    [string]$ArgumentsToSourceExe,
    [string]$ShortCutName = "AppName"

    )
    #Build ShortCut Information

    $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    $DestinationPath = "$ShortCutFolderPath\$($ShortCutName).lnk"
    Write-Output "Shortcut Creation Path: $DestinationPath"

    if ($ArgumentsToSourceExe){
        Write-Output "Shortcut = $SourceExePath -$($ArgumentsToSourceExe)"
    }
    Else {
        Write-Output "Shortcut = $SourceExePath"
    }
    

    #Create Shortcut
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($DestinationPath)
    $Shortcut.IconLocation = "$SourceExePath, 0"
    $Shortcut.TargetPath = $SourceExePath
    if ($ArgumentsToSourceExe){$Shortcut.Arguments = $ArgumentsToSourceExe}
    $Shortcut.Save()

    Write-Output "Shortcut Created"
}


$AppName = "WMIExplorer"
$FileName = "WMIExplorer.zip"
$ExpandPath = "$env:windir\system32"
$URL = "https://github.com/vinaypamnani/wmie2/releases/download/v2.0.0.2/WmiExplorer_2.0.0.2.zip"
$AppPath = "$ExpandPath\WMIExplorer.exe"
$ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

if (!(Test-Path -Path $AppPath)){
    Write-Output "$AppName Not Found, Starting Remediation"
    #Download & Extract to System32
    Write-Output "Downloading $URL"
    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
    if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
    else{Write-Output "Failed Downloaded"; exit 255}
    Write-Output "Starting Extraction of $AppName to $ExpandPath"
    Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
    if (Test-Path -Path $AppPath){
        Write-Output "Successfully Extracted Zip File"
        New-AppIcon -SourceExePath $AppPath -ShortCutName "WMIExplorer"
    }
    else{Write-Output "Failed Extract"; exit 255}
}
else {
    Write-Output "$AppName Already Installed"
}


if (!(Test-Path "$ShortCutFolderPath\$($AppName).lnk")){
    New-AppIcon -SourceExePath $AppPath -ShortCutName "WMIExplorer"
}
