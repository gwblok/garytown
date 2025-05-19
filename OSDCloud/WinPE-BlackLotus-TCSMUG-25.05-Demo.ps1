<# 
This Demo, 2 OSDCloud workspaces have been setup already
One with default Windows 11 24H2 WinPE (26100.1) and then my additional items (drivers, etc)

Then a duplicate of the first workspace was created, but patching the WinPE with the CU (26100.4061) and then adding the Black Lotus files.



#>
#Set GA Workspace
Set-OSDCloudWorkspace -WorkspacePath 'C:\OSDCloud-Win1124H2-AMD64-WinPE-10.0.26100.1'
New-OSDCloudUSB

#Set CU Workspace
Set-OSDCloudWorkspace -WorkspacePath 'C:\OSDCloud-Win1124H2-AMD64-WinPE-10.0.26100.4061'
New-OSDCloudUSB


#Copy the default WinPE & Apply the CU
Copy-Item -Path $ADKWinPE.FullName -Destination "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Force
Mount-WindowsImage -Path $MountPath -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1
Add-WindowsPackage -PackagePath $PatchPath -Path $MountPath -LogLevel Debug -Verbose
Dismount-WindowsImage -Path $MountPath -Save

Get-WindowsImage -ImagePath "$OSDCloudRootPath\AKDWinPEWIM\winpe.wim" -Index 1


#Update Flash Drive for 2023 Certs

$OSDCloudUSBFileSystemLabel = 'WINPE'
$USBBootVolume = Get-Volume | Where-Object {$_.DriveType -eq "Removable" -and $_.FileSystemType -eq "FAT32" -and $_.FileSystemLabel -eq $OSDCloudUSBFileSystemLabel} | Select-Object -First 1
$USBBootVolumeLetter = $USBBootVolume.DriveLetter
#https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#bkmk_windows_install_media
copy-item "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD" "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD.BAK" -Force -Verbose
Start-Process -FilePath C:\windows\system32\bcdboot.exe -ArgumentList "c:\windows /f UEFI /s $($USBBootVolumeLetter): /bootex" -Wait -NoNewWindow -PassThru
copy-item "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD.BAK" "$($USBBootVolumeLetter):\EFI\MICROSOFT\BOOT\BCD" -Force -Verbose
