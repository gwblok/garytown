<#
Yeah, so this is setting Dark Mode Theme at login.
I couldn't get the registry values to stick during OSD, so I'm trying this.
Alot of Default User profile reg values aren't sticking on Win 11 24H2, so I'm giving this a shot.
#>

$A = New-ScheduledTaskAction -Execute "C:\Windows\Resources\Themes\themeA.theme"
$T = New-ScheduledTaskTrigger -AtLogOn
$P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited
$task = New-ScheduledTask -Action $A -Trigger $T -Principal $P -Settings $S
$S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3 -RestartInterval (New-TimeSpan -Hours 1)
$task = New-ScheduledTask -Action $A -Trigger $T -Principal $P -Settings $S
Register-ScheduledTask -TaskName "Dark Mode on Logon" -InputObject $Task
