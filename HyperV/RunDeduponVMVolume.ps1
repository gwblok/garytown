<# Gary Blok @gwblok 

Run Deduplication on a VM Volume

#>

#Backup Location & Map Drive
$HostName = $env:computername
$BackupDrivePath = "F:"
$LogPath = "$BackupDrivePath\Logs"
$GetDate = Get-Date -Format "yyyy-MM-dd"


Start-Transcript -Path "$LogPath\$($HostName)-Dedup-$($GetDate).log"

$VMs = Get-VM | Where-Object {$_.State -eq "Running"}

#Stop All VMs and optimize the VHDx Files
foreach ($VM in $VMs){
    $Size = [math]::Round(((Get-ChildItem -Recurse $VM.path | Measure-Object -Property Length -Sum).Sum / 1GB),2)
    Write-Host "Starting Deduplication of VM $($VM.Name) | $Size GB" -ForegroundColor Cyan

    $VHDXPaths = $VM.HardDrives.path | Where-Object {$VM.HardDrives.DiskNumber -eq $null}
    if ($VHDXPaths){
        Get-VM -Name $VM.Name | Stop-VM -Force
        ForEach ($VHDXPath in $VHDXPaths)
            {
            $SizeBefore = (Get-Item -Path $VHDXPath).length
            Write-Host " Size of $((Get-Item -Path $VHDXPath).Name) = $($SizeBefore/1GB) GB" -ForegroundColor Green
            Write-Host " Optimzing VHD $VHDXPath on $($VM.Name)" -ForegroundColor Green
            Optimize-VHD -Path $VHDXPath -Mode Full
            $SizeAfter = (Get-Item -Path $VHDXPath).length
            $Diff = $SizeBefore - $SizeAfter
            Write-Host " Size After: $($SizeAfter/1GB) GB | Saving $($Diff /1GB) GB" -ForegroundColor Green
            }
        #Get-VM -Name $VM.Name | Start-VM
    }
    else{ Write-Host "$($VM.Name) Has no associated VHDx Files" -ForegroundColor Yellow
    }
}

if ((Get-VM | Where-Object {$_.State -eq "Running"}).count -eq 0){
    Start-DedupJob -Volume "D:" -Type Optimization -Wait -Verbose
    Start-DedupJob -Volume "G:" -Type Optimization -Wait -Verbose
    
}
foreach ($VM in $VMs){
    Get-VM -Name $VM.Name | Start-VM
    Write-Host "Starting VM $($VM.Name)" -ForegroundColor Cyan
    Start-Sleep -Seconds 60
}
Start-DedupJob -Volume "F:" -Type Optimization
Stop-Transcript
