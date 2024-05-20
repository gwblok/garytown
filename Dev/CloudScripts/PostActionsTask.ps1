$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath = "$env:ProgramData\OSDCloud\PostActions.ps1"
$ScheduledTaskName = 'OSDCloudPostAction'


if (!(Test-Path -Path ($ScriptPath | split-path))){New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null}
New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
New-ItemProperty -Path $RegistryPath -Name "TriggerPostActions" -PropertyType dword -Value 1 | Out-Null



$action = (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath")
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
Register-ScheduledTask $ScheduledTaskName -InputObject $task -User SYSTEM



#Script That Runs:
$PostActionScript = @'

$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScheduledTaskName = 'OSDCloudPostAction'

#Get Current Run, Cleanup if = 5
[int] $CurrentRun = Get-ItemPropertyValue -Path $RegistryPath -Name 'TriggerPostActions'
if ($CurrentRun -ge 5){Unregister-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue}
    
#Update Post Actions Count
$UpdateCountTo = $CurrentRun + 1
New-ItemProperty -Path $RegistryPath -Name "TriggerPostActions" -PropertyType dword -Value $UpdateCountTo -force | Out-Null

#Import Functions from GitHUb
iex (irm functions.garytown.com)

#Update TimeZone 
Set-TimeZoneFromIP

#Trigger Store Updates
Invoke-UpdateScanMethodMSStore

#Enable Microsoft Other Updates:
(New-Object -com "Microsoft.Update.ServiceManager").AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

#Enable "Notify me when a restart is required to finish updating"
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType dword -Value 1



#Wait and retrigger Store Updates
Start-Sleep -Seconds 100
Invoke-UpdateScanMethodMSStore

'@

$PostActionScript | Out-File -FilePath $ScriptPath -Force
