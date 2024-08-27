#Script Returns the Disk Number for the Desired Disk for installing Windows to during OSD

$Disks = Get-Disk
if (!($Disks)){
    restart-service smphost
    start-sleep 5
}

#BusTypes
#https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/msft-disk

$BusType = 'NVMe'  #This is the priority for loading the OS to
$BusTypesSkip = @("Fiber Channel","USB","iSCSI","Storage Spaces") #if can't find NVMe, grab something else, but NOT these!
$Disks = Get-Disk | Where-Object {$_.BusType -Match $BusType}  

#If Non-Found, just use the smallest disk size:
if (!$disk){
    $DiskNumber = (get-disk | Where-Object {$_.size -eq ((get-disk | Where-Object {$_.BusType -notin $BusTypesSkip}).size | measure -Minimum).Minimum}).Number
}
#If found, get the smallest one (just incase there is more than one)
else{
    $DiskNumber = ($Disks | Where-Object {$_.size -eq ((get-disk | Where-Object {$_.BusType -match $BusType}).size | measure -Minimum).Minimum}).Number
}

return $DiskNumber
