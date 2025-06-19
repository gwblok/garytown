<#GARYTOWN.COM
Creates: 
- C:\ProgramData\BGInfo\ with several files
- Registry Key HKLM:\SOFTWARE\2Pint Software\BGinfo
- 2 Scheduled Tasks:
    - BGInfo-USER: Runs at user logon with a 1-minute delay
    - BGInfo-SYSTEM: Runs at system logon

Current solution will:
- Download Script that runs at logon (same script for both user and system logon) but runs differently based on the user context
- Download BGInfo from Sysinternals
- Create a scheduled task to run BGInfo at user logon with a 1-minute delay - This triggers BGInfo to load the background image and system information
- Create a scheduled task to run BGInfo at system logon - This builds the registry keys and directories needed for BGInfo to run correctly

When Scheduled Task runs, it will:
- Check if the BGInfo.bgi file exists, if not, it will download it from the specified URL
- Check OS (Client or Server) and set the appropriate background image
- Check Resolution and set the appropriate background image
#>

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


# Create Scheduled Task to run at logon with a 1-minute delay
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ExpandPath\BGInfo_ScheduledTaskScript.ps1`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Trigger.delay = 'PT1M'
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run BGInfo at user logon with 2-minute delay"
Register-ScheduledTask -TaskName "BGInfo-USER" -InputObject $Task -Force

#Create Scheduled Task to run at logon
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ExpandPath\BGInfo_ScheduledTaskScript.ps1`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run BGInfo at user logon"
Register-ScheduledTask -TaskName "BGInfo-SYSTEM" -InputObject $Task -Force