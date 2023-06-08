<#
     .Author 
      Gary Blok | HP Inc | @gwblok | GARYTOWN.COM
      Dan Felman | HP Inc | @dan_felman 
 
     .Synopsis
      HP Dock Updater Script for Intune Proactive Remediation | Configuration Manager Configuration Items

     .Description
      This script will call the functions to detect and or update the Dock Firmware based on variables set at start.

     .Requirements
      PowerShell on the device you're running the script must have access to the interent to download the Firmware

     .Parameters 
      See embedded function Get-HPDockUpdateDetail for more info

     .ChangeLog

     .Notes
     
     For Intune set Purpose to "IntunePR"
     For ConfigMgr Set Purpose to "ConfigMgr"

     For Detect/Discovery, set $Remediate = $false
     For Remediation, Set $Remedation = $true

    #>


#Purpose: ConfigItem (Configuratn Manager) | IntunePR (Intune Proactive Remedation)
$Purpose = "IntunePR"
$Remediate = $true #Use for Detect if $false | Remedaite if $true
$Compliance = "Compliant"

### Grab Function Get-HPDockUpdateDetails and Paste Here: https://github.com/gwblok/garytown/edit/master/hardware/HP/Docks/Function_Get-HPDockUpdaterDetails.ps1

#Replace this next line with the content of the actual function when running in production.  Right now it pulls the function from Github directly when running.
iex (irm "https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdaterDetails.ps1")


### Function Ends

$DockInfo = Get-HPDockUpdateDetails
if ($DockInfo.UpdateRequired -eq $true){ #Update Required
    if ($Remediate -eq $false){ # NO Remediation (Discovery / Detection)
        if ($Purpose -eq "IntunePR") { exit 1} #Intune PR
        else { #ConfigMgr Configuration Item
            $Compliance = "Non-Compliant"
            return $Compliance
        }
    } #End NO Remediation ($false)
    if ($Remediate -eq $true){ #Run Update Process for Firmware
       #Run Function with Paramters to Update the Firmware showing a non-interactive UI and creating a Transcript file of the process.
       Get-HPDockUpdateDetails -UIExperience NonInteractive -Update -Transcript -Stage
    }
}
else{ #NO Dock Update Available / Needed
    if ($Purpose -eq "IntunePR") { exit 0} #Intune PR
    else{ return $Compliance} #ConfigMgr Configuration Item
}
