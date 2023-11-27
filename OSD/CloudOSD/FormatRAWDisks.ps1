#Gets Readout and Prints to console (SMSTSLog) Before Changes
get-disk

#Change CD Drive to A Drive temporary
$cd = Get-WMIObject -Class Win32_CDROMDrive -ErrorAction Stop
if ($cd){
    $driveletter = $cd.drive
    $DriveInfo = Get-CimInstance -class win32_volume | Where-Object {$_.DriveLetter -eq $driveletter} |Set-CimInstance -Arguments @{DriveLetter='A:'}
}
#Get RAW Disks and Format
$RAWDisks = get-disk | Where-Object {$_.PartitionStyle -eq "RAW" -and $_.BusType -ne "USB"}
foreach ($Disk in $RAWDisks)#{}
    {
    $Size = [math]::Round($Disk.size / 1024 / 1024 / 1024)
    Initialize-Disk -PartitionStyle GPT -Number $Disk.Number
    New-Partition -DiskNumber $Disk.Number -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "Storage-$($size)GB" -Confirm:$false 
    }

if ($cd){
    #Set CD to next available Drive Letter
    $AllLetters = 67..90 | ForEach-Object {[char]$_ + ":"}
    $UsedLetters = get-wmiobject win32_logicaldisk | select -expand deviceid
    $FreeLetters = $AllLetters | Where-Object {$UsedLetters -notcontains $_}
    $CDDriveLetter = $FreeLetters | select-object -First 1
    $DriveInfo = Get-CimInstance -class win32_volume | Where-Object {$_.DriveLetter -eq "A:"} |Set-CimInstance -Arguments @{DriveLetter=$CDDriveLetter}
}
#Gets Readout and Prints to console (SMSTSLog) After Changes
get-disk
