#GARYTOWN.COM

$BGInfoScript = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/BGInfo_ScheduledTaskScript.ps1"
$ExpandPath = "$env:programdata\BGInfo"

#Setup Folders & Registry
if (-not (Test-Path -Path $ExpandPath)) {
    Write-Output "Creating Directory: $ExpandPath"
    New-Item -ItemType Directory -Path $ExpandPath -Force
}
if (-not(Test-Path -path 'HKLM:\SOFTWARE\2Pint Software\BGinfo')){
    New-Item -Path 'HKLM:\SOFTWARE\2Pint Software\BGinfo' -ItemType directory -Force | Out-Null
}
$BGInfoScript | Out-File -FilePath "$ExpandPath\BGInfo_ScheduledTaskScript.ps1" -Force -Encoding UTF8


#Create Scheduled Task to run at logon
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ExpandPath\BGInfo_ScheduledTaskScript.ps1`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run BGInfo at user logon"
Register-ScheduledTask -TaskName "BGInfo" -InputObject $Task -Force