# HP MIK Client Install / Updater Configuration Items

CI Detection Method: <br>

```PowerShell
$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match "HP"){Write-Output $Manufacturer}
elseif ($Manufacturer -match "Hewlett"){Write-Output $Manufacturer}
else{}
```

Settings: Discovery Script <br>
https://github.com/gwblok/garytown/blob/master/hardware/HP/MIK/MIKClient_CI_Discovery.ps1

Settings: Remediation Script<br>
https://github.com/gwblok/garytown/blob/master/hardware/HP/MIK/MIKClient_CI_Remediation.ps1
