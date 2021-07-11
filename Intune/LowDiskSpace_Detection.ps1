#GARYTOWN.COM - @GWBLOK
#Detection script for Low Disk Space
# Set the Min Free Space to what you want.. make sure you update both this and the remdiation script to the same value

$MinFreeSpace = 25GB
Function Get-FreeSpace {$DriveInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"; $Global:FreeSpace = $DriveInfo.FreeSpace; return $FreeSpace}
if ((Get-FreeSpace) -lt $MinFreeSpace){exit 1}
