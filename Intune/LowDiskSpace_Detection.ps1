#GARYTOWN.COM - @GWBLOK
#Detection script for Low Disk Space
# Set the Min Free Space to what you want.. make sure you update both this and the remdiation script to the same value

$MinFreeSpace = 25GB
Function Get-FreeSpace {$DriveInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"; $Global:FreeSpace = $DriveInfo.FreeSpace; return $FreeSpace}
if ((Get-FreeSpace) -lt $MinFreeSpace){exit 1}

#Directories I just don't want on my machines  If they exist, I want to delete them.  This is a detection script, so if they exist, it will return a 1 and the remediation script will run.  If they don't exist, it will return a 0 and the remediation script won't run.
$Directories = @("C:\Drivers","C:\OSDCloud")
foreach ($Directory in $Directories){
    if (Test-Path $Directory){
        exit 1
    }
}