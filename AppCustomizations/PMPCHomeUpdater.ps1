$PMPCHomeUpdaterURL = "https://homeupdater.patchmypc.com/public/PatchMyPC-HomeUpdater-Portable.exe"
$PMPCHomeUpdaterFolderPath = "$env:SystemDrive\Windows\Temp\PMPC"
$PMPCHomeUpdaterPath = "$env:SystemDrive\Windows\Temp\PMPC\PatchMyPC-HomeUpdater-Portable.exe"
$PMPCRegPath = "HKLM:\SOFTWARE\Patch My PC\TOS"

# Download the Patch My PC Home Updater if it doesn't exist using BITS and Invoke-WebRequest as fallback
if (-Not (Test-Path -Path $PMPCHomeUpdaterFolderPath)) {
    New-Item -ItemType Directory -Path $PMPCHomeUpdaterFolderPath -Force | Out-Null
}    
if (-Not (Test-Path -Path $PMPCHomeUpdaterPath)) {
    Write-Host "Downloading Patch My PC Home Updater..." -ForegroundColor Cyan
    try {
        Start-BitsTransfer -Source $PMPCHomeUpdaterURL -Destination $PMPCHomeUpdaterPath -ErrorAction Stop
    } catch {
        Write-Host "BITS transfer failed, falling back to Invoke-WebRequest..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $PMPCHomeUpdaterURL -OutFile $PMPCHomeUpdaterPath -ErrorAction Stop
        } catch {
            Write-Host "Failed to download Patch My PC Home Updater." -ForegroundColor Red
        }
    }
} else {
    Write-Host "Patch My PC Home Updater already exists at $PMPCHomeUpdaterPath" -ForegroundColor Green
}

New-Item -Path $PMPCRegPath -ItemType Directory -Force | Out-Null
Set-ItemProperty -Path $PMPCRegPath -Name "Accepted" -Value 'True' -Type String -Force | Out-Null
Set-ItemProperty -Path $PMPCRegPath -Name "ShowSchedulerReminder" -Value 'False' -Type String -Force | Out-Null
Set-ItemProperty -Path $PMPCRegPath -Name "Date" -Value '1/3/2026 4:25:17 PM' -Type String -Force | Out-Null
Set-ItemProperty -Path $PMPCRegPath -Name "TelemetryReportedVersion" -Value '5.4.2.0' -Type String -Force | Out-Null
Set-ItemProperty -Path $PMPCRegPath -Name "Version" -Value '2.0' -Type String -Force | Out-Null

#Create Scheduled Task to run Patch My PC Home Updater at Noon Every Day
$Action = New-ScheduledTaskAction -Execute $PMPCHomeUpdaterPath -Argument "/silent"
$Trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
$TaskName = "Patch My PC Home Updater Daily"
if (-Not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -TaskName $TaskName -Description "Runs Patch My PC Home Updater daily at noon." | Out-Null
    Write-Host "Scheduled Task '$TaskName' created successfully." -ForegroundColor Green
} else {
    Write-Host "Scheduled Task '$TaskName' already exists." -ForegroundColor Yellow
}


Write-Host "Launching Patch My PC Home Updater..." -ForegroundColor Cyan
Start-Process -FilePath $PMPCHomeUpdaterPath -ArgumentList "/silent" -Wait