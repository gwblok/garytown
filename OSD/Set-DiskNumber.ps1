#Script Returns the Disk Number for the Desired Disk for installing Windows to during OS
#Get NVMe Disk
$BusType = 'NVMe'
$Disks = Get-Disk | Where-Object {$_.BusType -Match $BusType}
#If Non-Found, just use the smallest disk size:
if (!($Disks)){
    $DiskNumber = (get-disk | Where-Object {$_.size -eq ((get-disk | Where-Object {$_.BusType -notmatch "USB"}).size | measure -Minimum).Minimum}).Number
}
#If found, get the smallest one (just incase there is more than one)
else{
    $DiskNumber = ($Disks | Where-Object {$_.size -eq ((get-disk | Where-Object {$_.BusType -match $BusType}).size | measure -Minimum).Minimum}).Number
}
return $DiskNumber
