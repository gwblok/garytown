#Script Returns the Disk Number for the Desired Disk for installing Windows to during OSD
#https://garytown.com/osd-with-multi-disk-configs
#https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/msft-disk
$BusTypes = @('NVMe', 'SATA')
#if can't find NVMe, grab something else, but NOT these!
$BusTypesSkip = @("Fiber Channel", "USB", "iSCSI", "Storage Spaces")
#minimum size advised for system build (OS + programs + data)
$MinSize = 200GB
$DiskProps = { $_.BusType -in $BusTypes -and $_.BusType -notin $BusTypesSkip -and $_.Size -ge $MinSize }
$Disks = Get-Disk | Where-Object $DiskProps
if (-not ($Disks)) {
    restart-service smphost
    Start-Sleep -Seconds 5
    $Disks = Get-Disk | Where-Object $DiskProps
}
if (-not $Disks) { exit '0x80070490'} #unable to find a volume
$DiskNumber = ($Disks | Sort-Object Size | Select-Object -First 1).Number
return $DiskNumber
