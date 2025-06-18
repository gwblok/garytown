#GARYTOWN.COM

$BGInfoScript = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/BGInfo_ScheduledTaskScript.ps1"

#Create Scheduled Task to run at logon
$Action = New-ScheduledTaskAction -Execute $BGinfoPath -Argument $BGInfoArgs
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run BGInfo at user logon"
Register-ScheduledTask -TaskName "BGInfo" -InputObject $Task -Force