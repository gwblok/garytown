#Gary Blok | @gwblok | GARYTOWN.COM
#region Create Scheduled Task
[String]$TaskName = "Run PowerShell Script from GitHub Daily & on Event"

$PSCommand = 'iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Set-HPDockHistory_WMI.ps1)'


#Create Scheduled task:
#Action to Trigger:
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ep bypass -command `"$PSCommand`""

#Trigger on Event: 
$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
$Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
$Trigger.Subscription = @"
<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name='nhi'] and EventID=9008]]</Select></Query></QueryList>
"@
$Trigger.Delay = 'PT1M'
$Trigger.Enabled = $True 

#Trigger daily as well
$Trigger2 = New-ScheduledTaskTrigger -Daily -At '1:15 PM' -RandomDelay "02:00" -DaysInterval 1

#Combine Triggers
$triggers = @()
$triggers += $Trigger
$triggers += $Trigger2

#Run as System
$Prin = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

#Stop Task if runs more than 60 minutes
$Timeout = (New-TimeSpan -Minutes 60)

#Other Settings on the Task:
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit $Timeout

#Create the Task
$task = New-ScheduledTask -Action $action -principal $Prin -Trigger $triggers -Settings $settings

#Register Task with Windows
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force -ErrorAction SilentlyContinue

#endregion
