<#
CI Name: Black Lotus Step 2
Setting Name: Black Lotus Step 2 Reboot
NOTE, this is 2 of 2 Settings for this CI
#>
<# 
    Gary Blok & Mike Terrill
    KB5025885 Reboot Discovery
    Step 2 of 4
    Version: 25.05.12
#>

#Check to see if a reboot is required
$taskName = "Secure-Boot-Update"
$taskPath = "\Microsoft\Windows\PI\"
try {
    $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
    $taskInfo = $task | Get-ScheduledTaskInfo
    $lastRunResult = $taskInfo.LastTaskResult
  
    if ($null -ne $lastRunResult) {
        if ($lastRunResult -eq 2147942750) {
            #Write-Warning "Error 0x8007015E: No action was taken as a system reboot is required."
            $Reboot = "Non-compliant"
        }
        else {
            #Write-Warning "LastRunResult is empty. The task may not have run yet or data is unavailable."
            $Reboot = "Compliant"
        }
    }
}
catch {
    #Write-Warning "Failed to retrieve task information for $taskName at $taskPath : $_"
    #Assume Reboot is compliant
    $Reboot = "Compliant"
}

$Reboot