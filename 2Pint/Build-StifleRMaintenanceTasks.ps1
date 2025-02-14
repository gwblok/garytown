<#
.SYNOPSIS
    This script will create the folders, scripts, and tasks for performing basic StifleR maintenance.

.DESCRIPTION
    The script sets up the necessary directory structure, places the required scripts, and creates scheduled tasks to automate StifleR maintenance tasks.

.AUTHOR
    2Pint Software

.VERSION
    25.2.14
#>


#Please ensure that the following folders exist before running this script, adjust the paths as necessary
$StifleRParentFolder = "C:\Program Files\2Pint Software"
$gMSAAccountName = "gMSA_StifleRMaintenance"

#Create Folder Structure
$StifleRMaintenanceFolder = "$StifleRParentFolder\StifleR Maintenance"
$StifleRMaintenanceLogFolder = "$env:ProgramData\2Pint Software\StifleR Maintenance\Logs"

# Create the StifleR Maintenance folder if it doesn't exist
if (-Not (Test-Path -Path $StifleRMaintenanceFolder)) {
    New-Item -ItemType Directory -Path $StifleRMaintenanceFolder -Force | Out-Null
}

# Create the StifleR Maintenance Log folder if it doesn't exist
if (-Not (Test-Path -Path $StifleRMaintenanceLogFolder)) {
    New-Item -ItemType Directory -Path $StifleRMaintenanceLogFolder -Force | Out-Null
}

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

#Creates Scheduled Task in 2Pint Software Folder in Scheduled Tasks
function New-StifleRMaintenanceTask {
    param (
        [string]$TaskName = "StifleRMaintenance",
        [string]$ScriptPath = "C:\Program Files\2Pint Software\StifleR Maintenance\script.ps1",
        [string]$gMSAAccountName = "gMSA_StifleRMaintenance",
        [string]$timeofday = "2:00AM"
    )
    
    if (Test-ScheduledTaskExists -TaskName $TaskName) {
        Write-Host "Scheduled task '$TaskName' already exists."
        return
    }
    
    # Define the name of the new folder
    $folderName = "2Pint Software"

    # Create a new scheduled task folder
    $taskService = New-Object -ComObject Schedule.Service
    $taskService.Connect()
    try {
        $taskService.GetFolder("$folderName") | Out-Null
    }
    catch {
        $rootFolder = $taskService.GetFolder("\")
        $rootFolder.CreateFolder($folderName) | Out-Null
    }

    Write-Output "Scheduled task folder '$folderName' created successfully."
    
    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

    # Define the trigger for the scheduled task (daily at 2 AM)
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeofday

    # Register the scheduled task
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Description "Daily StifleR Maintenance Task" -User $gMSAAccountName  -RunLevel Highest -TaskPath "\2Pint Software" -Force
}


# Example usage
#New-StifleRMaintenanceTask

#Create Maintenance Scripts - Clean up Stale Objects
$RemoveStifleRStaleClientsScriptContent = @'

'@

$RemoveStifleRStaleClientsScriptContent | Out-File -FilePath "$StifleRMaintenanceFolder\Remove-StifleRStaleClients.ps1" -Force
New-StifleRMaintenanceTask -TaskName "Remove StifleR Stale Clients" -ScriptPath "$StifleRMaintenanceFolder\Remove-StifleRStaleClients.ps1" -gMSAAccountName $gMSAAccountName -timeofday "3:00AM"


#Create Maintenance Scripts - Clean up Duplicate Objects
$RemoveStifleRDuplicateClientsScriptContent = @'

'@

$RemoveStifleRDuplicateClientsScriptContent | Out-File -FilePath "$StifleRMaintenanceFolder\Remove-StifleRDuplicates.ps1" -Force
New-StifleRMaintenanceTask -TaskName "Remove StifleR Duplicate Clients" -ScriptPath "$StifleRMaintenanceFolder\Remove-StifleRDuplicates.ps1" -gMSAAccountName $gMSAAccountName -timeofday "4:00AM"