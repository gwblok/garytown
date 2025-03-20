[CmdletBinding()]
Param (

        [Parameter(Mandatory=$false)]
        [int]$RequiredFree = 20
                )

$SystemDrive = ($env:SystemDrive).Replace(":","")
$OSVolume = Get-Volume -DriveLetter $SystemDrive

#Get Disk in GB
$OSVolumeSize = $OSVolume.Size /1024 /1024 /1024

#Calculate Required Free Space in GB based on RequiredFree percentage
$RequiredFreeGB = $OSVolumeSize * $RequiredFree / 100
#Round RequiredFreeGB
$RequiredFreeGB = [math]::Round($RequiredFreeGB, 0)

#Get Free Space in GB
$OSVolumeFreeSpace = $OSVolume.SizeRemaining /1024 /1024 /1024
#Round OSVolumeFreeSpace
$OSVolumeFreeSpace = [math]::Round($OSVolumeFreeSpace, 0)

$Return =  ($RequiredFree -gt $OSVolumeFreeSpace)

return $Return