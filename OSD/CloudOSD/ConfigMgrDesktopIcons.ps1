#Gary Blok | @gwblok | Recast Software
#Create ConfigMgr Control Panel Shortcut & Software Center Shortcut on Desktop

#Build ShortCut Information
$SourceExe = "$env:windir\system32\control.exe"
$ArgumentsToSourceExe = "smscfgrc"
$DestinationPath = "$env:Public\Desktop\ConfigMgr Panel.lnk"

#Create Shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.IconLocation = "C:\Windows\System32\SHELL32.dll, 14"
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()

write-output "Creating ConfigMgr Control Panel Icon on Desktop"


#Build ShortCut Information
$SourceExe = "$env:windir\CCM\ClientUX\SCClient.exe"
$ArgumentsToSourceExe = "softwarecenter:Page=AvailableSoftware"
$DestinationPath = "$env:Public\Desktop\Software Center.lnk"

#Create Shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()

write-output "Creating ConfigMgr Software Center Icon on Desktop"
