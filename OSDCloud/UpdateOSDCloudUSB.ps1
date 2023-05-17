Update-Module -name OSD -Force
import-module -name OSD -Force

#Clear old OSD Modules from WorkSpace
$CloudWorkSpace = Get-OSDCloudWorkspace
Remove-Item -Path "$CloudWorkSpace\PowerShell\Offline\Modules\OSD" -Force -Recurse -ErrorAction SilentlyContinue

#Clear old OSD Modules from Flash Drives
$FlashDrives = get-volume | Where-Object {$_.DriveType -eq "Removable"}
Foreach ($FlashDrive in $FlashDrives){
     if (test-path -path "$($FlashDrive.DriveLetter)\OSDCloud\PowerShell\Offline\Modules\OSD"){
        Remove-Item -Path "$($FlashDrive.DriveLetter)\OSDCloud\PowerShell\Offline\Modules\OSD" -Force -Recurse -ErrorAction SilentlyContinue

     }
}


Edit-OSDCloudWinPE #Updates the latest version of OSD module in the WinPE boot image
Update-OSDCloudUSB -PSUpdate #Updates the USB Stick with the latest PS Modules & Boot Image that was just updated.
