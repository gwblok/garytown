<# Gary Blok @gwblok 

Still building - Cleanup of Backups

#>

#Backup Location & Map Drive
$HostName = $env:computername
if ($HostName -eq "UGreen"){
    $BackupDrivePath = "F:\HyperVBackups"
    
}
else{
    $BackupURLPathRoot = "\\UGreen\HyperVBackups$"
    $BackupDrivePath = "V:"
    if (-not (Test-Path -Path $BackupDrivePath)){
        net use $BackupDrivePath  $BackupURLPathRoot /user:VMBackup 'P@ssw0rd' /persistent:no
    }
    if (-not (Test-Path -Path $BackupDrivePath)){Write-Host "Failed to Map Drive" -ForegroundColor Red;return}
    else{Write-Host "Mapped Drive $BackupDrivePath to $BackupURLPathRoot" -ForegroundColor Green}
}

$LogPath = "$BackupDrivePath\Logs"
$GetDate = Get-Date -Format "yyyy-MM-dd"
$VMsBackups2Cleanup = @()
Get-ChildItem -Path $BackupDrivePath -Directory | Where-Object {$_.Name -ne "Logs"} | ForEach-Object {
    $VMsBackups2Cleanup += Get-ChildItem -Path $_.FullName -Directory | Where-Object {$_.Name -ne $GetDate}
}

Start-Transcript -Path "$LogPath\$($HostName)-$($GetDate).log"
#Report on VMs to Cleanup
Foreach ($VM in $VMsBackups2Cleanup){
    Write-Host "Cleaning up Backups of VM $($VM.Name)" -ForegroundColor Cyan
}

#Get the VMs Backups and find the ones to Cleanup
Foreach ($VM in $VMsBackups2Cleanup){
    $VMName = $VM.Name
    $Size = [math]::Round(((Get-ChildItem -Recurse $VM.FullName | Measure-Object -Property Length -Sum).Sum / 1GB),2)
    Write-Host "Starting Cleanup of VM $($VM.Name) | $Size GB" -ForegroundColor Cyan
    #Remove-Item -Path $VM.FullName -Recurse -Force
    $BackupInfoDB = @()
    foreach ($Folder in $VM.FullName){

        $BackupFolders = Get-ChildItem -Path $Folder
        #Get the Last Backup from each month
        $LastBackup = $BackupFolders | Sort-Object Name -Descending | Select-Object -First 1
        foreach ($BackupFolder in $BackupFolders){
        $BackupInfo = New-Object -TypeName    PSObject -Property @{
            VMName = $VMName
            BackupDate = [datetime]$BackupFolder.Name

        }
        $BackupInfoDB += $BackupInfo
        }
    }
    $OlderThan60Days = $BackupInfoDB | Where-Object {$_.BackupDate -lt (Get-Date).AddDays(-60)}
    #Write Function to Find the fist backup of each month from the backups older than 60 days
    $BackupsGroupedByMonthOlderThan60 = $OlderThan60Days | Group-Object {Get-Date $_.BackupDate -Format "yyyy-MM"}
    $FirstBackupOfMonthOlderThan60 = $BackupsGroupedByMonthOlderThan60 | ForEach-Object {
        $_.Group | Sort-Object BackupDate | Select-Object -First 1
    }
    $FirstBackupOfMonth = $BackupInfoDB | Group-Object {Get-Date $_.BackupDate -Format "yyyy-MM"} | ForEach-Object {
        $_.Group | Sort-Object BackupDate | Select-Object -First 1
    }
}

Stop-Transcript
