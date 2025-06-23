# set of functions to be called when I run bginfo.garytown.com

Write-Host "Loading BGInfo Web Functions..." -ForegroundColor Green


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


Function Build-BGInfoTasks {

    Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/BGINFO_DL_Launch.ps1')
}

Function Invoke-BGInfo {
    if (Test-ScheduledTaskExists -TaskName "BGInfo-USER"){
        Write-Host "Starting Task BGInfo-SYSTEM to populate the registry and directories..." -ForegroundColor Cyan
        Start-ScheduledTask -TaskName "BGInfo-SYSTEM" -ErrorAction SilentlyContinue
        Write-Host "Waiting for BGInfo-SYSTEM to complete..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
        Write-Host "Starting Task BGInfo-USER to set the background image and system information..." -ForegroundColor Cyan
        Start-ScheduledTask -TaskName "BGInfo-USER" -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "BGInfo Scheduled Tasks do not exist. Please run Build-BGInfoTasks first." -ForegroundColor Red
    }

}