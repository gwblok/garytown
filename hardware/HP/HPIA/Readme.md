# HP Image Assistant Scripts

HPIA-Functions.ps1 = snips, not actual script, just contains several Funtions to using HPIA via PowerShell <br>

## Standalone HPIA Automated Setup
HPIA-AutoUpdate-Setup.ps1 = Script to run on endpoints via any management system you want. <br>
Script will create scheduled task that will run HPIA<br>
See https://garytown.com/auto-updates-of-your-bios-drivers-with-hpia-hpcmsl-hp-connect for details


## Intune Proactive Rememdations
HPIA-PR-Detect.ps1<br>
HPIA-PR-Remediation.ps1<br>

These scripts are ment to be used with Intune PR, which will run HPIA to see if updates needed, if so, then triggers HPIA to run in full mode.
You could simplify if you like, just use the Remediation Script as Detection, and skip adding a Remedation Script... whatever floats your boat.  Blog post coming soon... probably.<br>

# CM Baselines:
https://garytown.com/using-configmgr-baseline-to-deploy-hpia-for-auto-updating-of-drivers

## CM Baseline - Create Scheduled Task
This will CREATE the Scheduled task on the endpoint, it does NOT trigger HPIA, only sets up the scheduled task and creates the HPIA script on the end point.
If you want the baseline to trigger HPIA directly, replicate the Intune Proactive Remediation process in CM instead.<br>

Create a Configuration Item: HPIA -Scheduled Task & Script Setup<br>
Setting Type: Script<br>
Data type: String<br>
<br>
Discovery Script: HPIA-CI-Setup-Discovery.ps1<br>
Remediation Script: HPIA-AutoUpdate-Setup.ps1<br>
Detection Method:<br>
```PowerShell
$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match "HP"){Write-Output $Manufacturer}
elseif ($Manufacturer -match "Hewlett"){Write-Output $Manufacturer}
else{}
```
Complance Rule: value returned = Compliant<br>
Check Box "Run the specifiied remedmation script when this setting is noncompliant" - CHECKED<br>
Check Box "Report noncompliance if the setting instance if not found" - CHECKED<br>

CM Baseline Export: HPIA Scheduled Task Setup.cab

## CM Baseline - Run HPIA
This will run HPIA directly from the Baseline instead of creating a scheduled task.

Create a Configuration Item: HPIA Driver Updates<br>
Discovery Script: HPIA-CI-Run-HPIA-Discovery.ps1<br>
Remediation Script: HPIA-PR-Remediation.ps1<br>
Detection Method: Same as above
Complance Rule: value returned = Compliant<br>
Check Box "Run the specifiied remedmation script when this setting is noncompliant" - CHECKED<br>
Check Box "Report noncompliance if the setting instance if not found" - CHECKED<br>

CM Baseline Export: Driver Updates via HPIA.cab
