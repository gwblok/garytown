<# Gary Blok @gwblok 
Used to backup VMs to Network (and Local Server)

Future Enchanments:
 - Add function to optimize the drives once the VMs are turned off to save space before backup. (Optimize-VHD)
#>

#Backup Location & Map Drive
$HostName = $env:computername
if ($HostName -eq "UGreen"){
    $BackupDrivePath = "G:\HyperVBackups"
    
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
$VMs = Get-VM
$VMs2Backup = @()
Start-Transcript -Path "$LogPath\$($HostName)-$($GetDate).log"

Foreach ($VM in $VMs){
    $WorkingVM = Get-VM -Name $VM.Name
    $Notes = $WorkingVM.Notes -split "`n"
    $Backup = $Notes | Where-Object {$_ -match "Backup"}
    if ($Backup){
            if ($Backup -match "True")
                {$Backup = $true}
            else
                {$Backup = $false}
        }
    if ($Backup -eq $true){
        $VMs2Backup += $WorkingVM
    }
}
Write-Host "VMs to Backup" -ForegroundColor Cyan
foreach ($VM in $VMs2Backup){
    $Size = [math]::Round(((Get-ChildItem -Recurse $VM.path | Measure-Object -Property Length -Sum).Sum / 1GB),2)
    Write-Host "VM: $($VM.Name) | $Size GB" -ForegroundColor Yellow
}

Foreach ($VM in $VMs2Backup){
    if ($VM.Name -match '|'){
        $VMName = ($VM.Name.Split('|') | Select-Object -First 1).trim()
    }
    else{
        $VMName = $VM.Name
    }
    $Size = [math]::Round(((Get-ChildItem -Recurse $VM.path | Measure-Object -Property Length -Sum).Sum / 1GB),2)
    Write-Host "Starting Backup of VM $($VM.Name) | $Size GB" -ForegroundColor Cyan
    $WorkingVM = Get-VM -Name $VM.Name
    #Server Path for Backup
    $Destination = "$BackupDrivePath\$HostName\$($VMName)\$GetDate"
    if (Test-path -Path $Destination){
        Write-Host "Destination Exists, Backup already completed Today" -ForegroundColor Yellow
        Write-Host "Skipping Backup of VM: $($VMName)" -ForegroundColor Yellow
    }
    else{
        Write-Host "Stopping VM $($VMName)" -ForegroundColor Cyan
        stop-vm -VM $VM -Force
        if ($HostName -eq "UGreen"){
            $Destination = "$BackupDrivePath\$HostName\$($VMName)\$GetDate"
            [void][System.IO.Directory]::CreateDirectory($Destination)
            Write-Host "Exporting VM $($VMName) to $TempLocation" -ForegroundColor Cyan
            export-vm -VM $VM -Path $Destination
            Write-Host "Starting VM $($VMName)" -ForegroundColor Cyan
            Start-VM -VM $VM
        }
        else{
            #Temp Location Local for Export
            $TempLocation = "$env:TEMP\HyperV"
            if (Test-Path -Path $TempLocation){Remove-Item -Path $TempLocation -Recurse -Force}
            [void][System.IO.Directory]::CreateDirectory($TempLocation)
            Write-Host "Exporting VM $($VMName) to $TempLocation" -ForegroundColor Cyan
            export-vm -VM $VM -Path $TempLocation
            Write-Host "Starting VM $($VMName)" -ForegroundColor Cyan
            Start-VM -VM $VM
        
            #Backup to Server Share
            [void][System.IO.Directory]::CreateDirectory($Destination)
            Write-Host "Backing up VM $($VMName) to $Destination" -ForegroundColor Green
            Copy-Item -Path "$TempLocation\$($VM.Name)" -Destination "$Destination" -Recurse
        }
    }
}
Stop-Transcript
