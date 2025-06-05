function New-ScheduleTaskPowerShellScript {
    [CmdletBinding()]
    param (
        [string]$TaskName = "Manage VMs",
        [string]$ScriptPath,
        [string]$UserAccount = "SYSTEM",
        [string]$timeofday = "8:00AM",
        [string]$TaskPath,
        [String]$description,
        [switch]$HyperVManage = $false
    )
    
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
    if (Test-ScheduledTaskExists -TaskName $TaskName) {
        Write-Host "Scheduled task '$TaskName' already exists."
        return
    }
    

    if (-not($description)) {
         $description = "`"Default description for the task created by function New-ScheduleTaskPowerShellScript`""
    }

    # If HyperVManage is true, set the script path to the HyperV management script.  Assumes you have the script in root\HyperV\Manage-VMLab.ps1
    if ($HyperVManage) {
        $Volumes = Get-Volume | where-object { $null -ne $_.DriveLetter }
        foreach ($Volume in $Volumes) {
            $ScriptPath = "$($Volume.DriveLetter):\HyperV\Manage-VMLab.ps1"
            if (Test-Path -Path $ScriptPath) {
                break
            }
        }
        if (-not(Test-Path -Path $ScriptPath)) {
            Write-Output "HyperV management script not found in any volume (EX: C:\HyperV\Manage-VMLab.ps1). Please ensure the script exists in the expected path."
            $ScriptPath = $null
        }
    }
    # If no script path is provided, throw an error
    if (-not $ScriptPath) {
        throw "ScriptPath parameter is required."
    }

    # Create a new scheduled task folder
    if ($TaskPath){
        $taskService = New-Object -ComObject Schedule.Service
        $taskService.Connect()
        try {
            $taskService.GetFolder("$TaskPath") | Out-Null
        }
        catch {
            $rootFolder = $taskService.GetFolder("\")
            $rootFolder.CreateFolder($TaskPath) | Out-Null
        }
    }
    
    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    # Define the trigger for the scheduled task (daily at 2 AM)
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeofday
    # Define the principal for the scheduled task
    $principal = New-ScheduledTaskPrincipal -UserId $UserAccount -LogonType Password -RunLevel Highest
    # Register the scheduled task
    Write-Verbose "Register-ScheduledTask -Action $action -Trigger $trigger -TaskName `"$TaskName`" $TaskPathArg $descriptionArg-Principal $principal  -Force "
    if ($TaskPath){
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$TaskName" -Principal $principal -Force -TaskPath $TaskPath
    }
    else {
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$TaskName" -Principal $principal -Force -TaskPath ".\"
    }
}
