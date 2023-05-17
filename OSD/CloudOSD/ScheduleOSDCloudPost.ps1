$action = (New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c rd c:\_SMSTaskSequence /S /Q"), (New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c rd c:\MININT /S /Q"),(New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c schtasks.exe/Delete /TN OSDCloudPost /F")
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Cleanup"
Register-ScheduledTask OSDCloudPost -InputObject $task -User SYSTEM
