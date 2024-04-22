$TaskName = "Shutdown Computer Daily 6PM"
$Compliance = $true



$GetTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (!($GetTask)){
    $Compliance = $false
}
else { #Based on settings I set in the scheduled task.  This is how you'd overwrite the task in the future if you deside to change a setting.
    if ($GetTask.Settings.ExecutionTimeLimit -ne 'PT1H'){$Compliance = $false}
    if ($GetTask.Settings.RestartInterval -ne 'PT1H'){$Compliance = $false}
    if ($GetTask.Settings.RestartCount -ne 3){$Compliance = $false}
    if ($GetTask.Actions.Execute -ne "shutdown.exe"){$Compliance = $false}
    if ($GetTask.Principal.RunLevel -ne "Highest"){$Compliance = $false}
    #if ($GetTask.Settings.MultipleInstances -ne 'IgnoreNew'){$Compliance = $false}
}

if ($Compliance -eq $false){
    
    #$A = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument 'Stop-Computer -Force'
    $A = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument '-s -f -t 120'
    $T = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At 6PM
    $P = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
    $S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3 -RestartInterval (New-TimeSpan -Hours 1)
    $S.CimInstanceProperties.Item('MultipleInstances').Value = 3
    $task = New-ScheduledTask -Action $A -Trigger $T -Principal $P -Settings $S
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force

}
else {
    Write-Output "Compliance: $Compliance"
}
