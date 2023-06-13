# HP Dock Functions and Information

Blog Posts: <br>
[HP Dock Registry & Inventory with ConfigMgr](https://garytown.com/hp-dock-registry-inventory-with-configmgr) <br>
[HP Dock WMI Provider Deployment & Inventory with ConfigMgr](https://garytown.com/hp-dock-wmi-provider-deployment-inventory-with-configmgr) <br>
[Updating HP Docks with Intune or ConfigMgr using PowerShell](https://garytown.com/updating-hp-docks-with-intune-or-configmgr-using-powershell) <br>

[HP Dock ConfigMgr Global Condition](https://garytown.com/hp-dock-configmgr-global-condition)<br>
[HP Docks Update via ConfigMgr App Model](https://garytown.com/hp-docks-update-via-configmgr-app-model) <br>
Main function that is used by all of the processes: Function_Get-HPDockUpdaterDetails.ps1 <br>

To check for newer firmware: HPDock_FirmwareLookup.ps1 <br>

## Intune Proactive Remediation
Detection / Remediation: HPDockUpdater_Intune_ConfigMgr.ps1 * <br>
 * Requires that you copy the Function into the script, contents from: Function_Get-HPDockUpdaterDetails.ps1


## ConfigMgr Configuration Item 

Detection Script (Not Discovery): HPDockUpdaterCI_DetectionScript.ps1 <br>
Discovery / Remediation: HPDockUpdater_Intune_ConfigMgr.ps1 * <br>
 * Requires that you copy the Function into the script, contents from: Function_Get-HPDockUpdaterDetails.ps1


## ConfigMgr Hardware Inventory
[HP Dock Registry & Inventory with ConfigMgr](https://garytown.com/hp-dock-registry-inventory-with-configmgr) <br>
MOF file information: <br>
* HPDocks.HWInvConfigurationMOF.txt | Add the contents of this file to your configuration.mof
* HPDocks.HWInvExt.mof | download and import this into your Default Settings Policy

See the blog post for details
