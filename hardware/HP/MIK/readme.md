# HP MIK Client Install / Updater Configuration Items

CI Detection Method: <br>

```PowerShell
$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match "HP"){Write-Output $Manufacturer}
elseif ($Manufacturer -match "Hewlett"){Write-Output $Manufacturer}
else{}
```
Compliance Rule:
Rule Type: Value [Drop down]
Operator: Equals [Drop down]
Values: Compliant [String Entry]

Settings: Discovery Script <br>
https://github.com/gwblok/garytown/blob/master/hardware/HP/MIK/MIKClient_CI_Discovery.ps1

Settings: Remediation Script<br>
https://github.com/gwblok/garytown/blob/master/hardware/HP/MIK/MIKClient_CI_Remediation.ps1
<br>
<br>
Remdiation Script for ConfigMgr CI
<br>
Checks for:<br>
 - HP MIK Version
 - HPIA Version

 - Test for HPCMSL - Installs specialized version based on HP Connect if HPCMSL is not already loaded on device.
   - This happens even in Discovery Script, as the Discovery relies on HPCMSL
   - Installs to: C:\Program Files\HPConnect\hp-cmsl-wl



Make sure to keep the $MIKSoftpaqID information current
https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPMIK.html
