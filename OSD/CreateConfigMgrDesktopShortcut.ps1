<# Gary Blok @gwblok - Recast Software
Creates a shortcut on the desktop for the ConfigMgr Control Panel Applet
I use this in my lab / test machines.
#>
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
