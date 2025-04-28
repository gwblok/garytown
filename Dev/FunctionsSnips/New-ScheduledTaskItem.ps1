function Test-ScheduledTaskExists {
    param (
        [string]$TaskName
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        return $true
    } else {
        return $false
    }
}
function New-ScheduledTaskItem {
    param (
        [string]$TaskName = "YourTestTask",
        [string]$ScriptPath = "C:\Program Files\Tasks\script.ps1",
        [string]$gMSAAccountName = "gMSA_StifleRMaintenance",
        [string]$timeofday = "2:00AM",
        [string]$Description,
        [string]$TaskFolderName,
        [switch]$UseSystemAccount
    )
    
    if (Test-ScheduledTaskExists -TaskName $TaskName) {
        Write-Host "Scheduled task '$TaskName' already exists."
        return
    }
    
    # Define the name of the new folder
    if ($TaskFolderName){
        $TaskPathArg = $TaskFolderName
            # Create a new scheduled task folder
        $taskService = New-Object -ComObject Schedule.Service
        $taskService.Connect()
        try {
            $taskService.GetFolder("$TaskFolderName") | Out-Null
        }
        catch {
            $rootFolder = $taskService.GetFolder("\")
            $rootFolder.CreateFolder($TaskFolderName) | Out-Null
        }
    }
    else{
        $TaskPathArg = '\'
    }


    
    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    # Define the trigger for the scheduled task (daily at 2 AM)
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeofday
    # Define the principal for the scheduled task
    $principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
    # Register the scheduled task
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -TaskPath $TaskPathArg -Description $Description -Force -Principal $principal
}