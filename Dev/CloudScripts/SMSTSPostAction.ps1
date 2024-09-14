
Start-Transcript -Path C:\windows\CCM\logs\smstspostaction.txt

iex (irm functions.garytown.com)
Install-Nuget
Install-PackageManagement
Install-Module -Name OSD
Install-ModuleHPCMSL
Set-ThisPC
Set-TimeZoneFromIP
Start-WindowsUpdate
Invoke-UpdateScanMethodMSStore

Stop-Transcript

Restart-Computer
