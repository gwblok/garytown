# Get the event log entries for system reboots
Function Get-RebootEvents {
    [CmdletBinding()]
    param (
        [int]$MaxEvents = 20
    )
    # Get the last 20 reboot events (Event ID 6005) from the System log
    $rebootEvents = Get-WinEvent -LogName System -MaxEvents $MaxEvents -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated
    return $rebootEvents
}
Function Get-ShutdownEvents {
    [CmdletBinding()]
    param (
        [int]$MaxEvents = 20
    )
    # Get the last 20 shutdown events (Event ID 6006) from the System log
    $shutdownEvents = Get-WinEvent -LogName System -MaxEvents $MaxEvents -FilterXPath "*[System[EventID=6006]]" | Select-Object -Property TimeCreated
    return $shutdownEvents
}
Function Get-WindowsUEFICA2023Capable{
    try {
        $SecureBootServicing = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -ErrorAction Stop
        $WindowsUEFICA2023Capable = $SecureBootServicing.GetValue('WindowsUEFICA2023Capable')
    }
    catch {return 0}
    if ($WindowsUEFICA2023Capable) {
        return $WIndowsUEFICA2023Capable
    }
    else  {return 0}
}
function Get-LastScheduledTaskResult {
    param (
        [string]$TaskName,
        [Switch]$OnlineLookup = $false
    )
    try {
        $Task = Get-ScheduledTask -TaskName $TaskName
        if ($null -eq $Task) {
            Write-Output "Scheduled Task '$TaskName' not found."
            return $null
        }

        $TaskHistory = Get-ScheduledTaskInfo -InputObject $Task
        $LastRunTime = $TaskHistory.LastRunTime
        $LastTaskResult = $TaskHistory.LastTaskResult
        if ($OnlineLookup){
            $LastTaskResultDescription = (Get-ErrorCodeDBInfo -ErrorCodeUnignedInt $LastTaskResult).ErrorDescription
        }
        else{
            $LastTaskResultDescription = "Unknown"
        }
        [PSCustomObject]@{
            TaskName       = $TaskName
            LastRunTime    = $LastRunTime
            LastTaskResult = $LastTaskResult
            LastTaskDescription = $LastTaskResultDescription
        }
    }
    catch {
        Write-Error "Error retrieving scheduled task result: $_"
    }
}

Function Get-SecureBootUpdateSTaskStatus{#Check to see if a reboot is required
    [CmdletBinding()]
    param ()
    $taskName = "Secure-Boot-Update"
    $Task = Get-ScheduledTask -TaskName $TaskName
    if ($null -eq $Task) {
        Write-Verbose "Scheduled Task '$TaskName' not found."
        return $null
    }
    $TaskHistory = Get-ScheduledTaskInfo -InputObject $Task
    $LastRunTime = $TaskHistory.LastRunTime
    $LastTaskResult = $TaskHistory.LastTaskResult
    if ($TaskHistory.LastTaskResult -eq 0) {
        $LastTaskResultDescription = "Successfully completed"
    }
    elseif ($TaskHistory.LastTaskResult -eq 2147942750) {
        $LastTaskResultDescription = "No action was taken as a system reboot is required."
    }
    elseif ($TaskHistory.LastTaskResult -eq 2147946825) {
        $LastTaskResultDescription = "Secure Boot is not enabled on this machine."
    }
    else {
        $LastTaskResultDescription = "Unknown error"
    }
    [PSCustomObject]@{
        TaskName       = $TaskName
        LastRunTime    = $LastRunTime
        LastTaskResult = $LastTaskResult
        LastTaskDescription = $LastTaskResultDescription
    }
}