$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument  "/C"
$trigger = New-ScheduledTaskTrigger -Daily -At 1AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -Hidden -WakeToRun
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
Register-ScheduledTask "Wake Device" -InputObject $task
