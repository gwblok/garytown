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
    $Compliance
    Exit 1
}
