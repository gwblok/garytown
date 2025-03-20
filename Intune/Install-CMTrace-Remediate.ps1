<#
Gary Blok - @gwblok - GARYTOWN.COM
.Synopsis
  Proactive Remediation for CMTrace to be on endpoint

 .Description
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

$AppName = "CMTrace"
$FileName = "CMTrace.exe"
$InstallPath = "$env:windir\system32"
$URL = "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/CMTrace.exe"
$AppPath = "$InstallPath\$FileName"
$ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

    $Params = @{
        Method = 'Head'
        Uri = $URL
        UseBasicParsing = $true
        Headers = @{'Cache-Control'='no-cache'}
    }

$CMTraceDownloadInfo = Invoke-WebRequest @Params

if (!(Test-Path -Path $AppPath)){
    Write-Output "$AppName Not Found, Starting Remediation"
    #Download & Transfer to System32
    Write-Output "Downloading $URL"
    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
    if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
    else{Write-Output "Failed Downloaded"; exit 255}
    Write-Output "Starting Copy of $AppName to $InstallPath"
    Copy-Item -Path $env:TEMP\$FileName -Destination $InstallPath -Force
    #Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
    if (Test-Path -Path $AppPath){
        Write-Output "Successfully Installed File"
        New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
    }
    else{Write-Output "Failed Extract"; exit 255}
}
else {
    Write-Output "$AppName Already Installed"
}




if (!(Test-Path "$ShortCutFolderPath\$($AppName).lnk")){
    New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
}