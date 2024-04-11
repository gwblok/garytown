
param(
    [Parameter(Mandatory=$false)]
    [string]$RepoLocation,
    [Parameter(Mandatory=$false)]
    [string]$CacheDir = "$env:TEMP\HPIACache",
    [Parameter(Mandatory=$false)]
    [string]$ToolLocation,
    [Parameter(Mandatory=$false)]
    [string]$LogLocation = "C:\Drivers"

)


if (!(Test-Path -Path $LogLocation)){
    New-Item -Path $LogLocation -ItemType Directory -Force | Out-Null
}
if (!(Test-Path -Path $CacheDir)){
    New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null
}

$TaskSequenceProgressUi = New-Object -ComObject "Microsoft.SMS.TSProgressUI" #Connect to TS Progress UI
$TaskSequenceProgressUi.CloseProgressDialog() #Close Progress Bar


Write-Output "============================================================"
Write-Output ""
Write-Output "RepoLocation: $($RepoLocation)"
Write-Output "LogLocation:  $($LogLocation)"
Write-Output "CacheDir:     $($CacheDir)"
Write-Output "ToolLocation: $($ToolLocation)"

Write-Output ""

$ToolPath = "$ToolLocation\HPImageAssistant.exe"
if (!(Test-Path -Path $ToolPath)){
    Write-Output "Unable to find $ToolPath"
    Exit 256
}

$ToolArg = "/Operation:Analyze /Action:Install /Selection:All /silent /ReportFolder:`"$LogLocation`" /SoftpaqDownloadFolder:`"$CacheDir`" /Offlinemode:`"$RepoLocation`" /Noninteractive /debug"

Write-Output "Start-Process -FilePath $ToolPath -ArgumentList $ToolArg -Wait -PassThru"
$Process = Start-Process -FilePath $ToolPath -ArgumentList $ToolArg -Wait -PassThru


Write-Output "ExitCode: $($Process.ExitCode)"

Write-Output ""
Write-Output "============================================================"
