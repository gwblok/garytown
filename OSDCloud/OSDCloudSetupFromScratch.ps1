#Make Sure you're running 24.3.20.1
Update-Module -name OSD -Force

#Restart PowerShell after OSD has been updated (if it needed to be updated)

#Setup WorkSpace Location
Import-Module -name OSD -force
$OSDCloudWorkspace = "C:\OSDCloudWinPE"
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)

#New Template (After you've updated ADK to lastest Version)
New-OSDCloudTemplate -Name "OSDCloudWinPE"

#New WorkSpace
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace
New-OSDCloudUSBSetupCompleteTemplate

#Added HPCMSL into WinPE
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL

#Create Cloud USB
New-OSDCloudUSB

#Update the Cloud USB drive
#Note, I found I need to add some parameters for it to sync over everything properly.
Update-OSDCloudUSB -OSName 'Windows 11 23H2' -OSActivation Retail
