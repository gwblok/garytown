<#
#Seems to be broken on Windows 11 22H2 - Need more testers to confirm.
- Works fine if you don't use ISE :-)

#Should return a list of BIN files on your System Volume
#>
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
$BinFiles = Get-ChildItem -LiteralPath $SystemVolume.path -Recurse | Where-Object {$_.name -match "bin"}
$BinFiles
