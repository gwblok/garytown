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

Write-Host "Launching Patch My PC Home Updater..." -ForegroundColor Cyan
Start-Process -FilePath $PMPCHomeUpdaterPath -ArgumentList "/silent" -Wait