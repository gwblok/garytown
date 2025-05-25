<# Gary Blok
Simple OSDCloud Setup Script for AMD64 (x64) WinPE
This script will assist in setting up OSDCloud from scratch, including creating a new template, workspace, and USB drive.
It will name the template & workspace based on the ADK WinPE version installed on the system.
#>


#Make Sure you're running Latest
Update-Module -name OSD -Force

#Restart PowerShell after OSD has been updated (if it needed to be updated)

#ADK Default Locations
$ADKAMD64WinPELocation = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim"
$ADKAMD64WinPEVersion = (Get-WindowsImage -ImagePath $ADKAMD64WinPELocation -Index 1).Version.replace('10.0.','')

$TemplateName = "OSDCloudWinPE-$($ADKAMD64WinPEVersion)"

#Setup WorkSpace Location
Import-Module -name OSD -force
$OSDCloudWorkspace = "C:\OSDCloudWinPE-$($ADKAMD64WinPEVersion)"
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)

#New Template (After you've updated ADK to lastest Version)
New-OSDCloudTemplate -Name $TemplateName

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
