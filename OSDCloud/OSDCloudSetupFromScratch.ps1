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

#Create the Template Name & Display Name in Console 
$TemplateName = "OSDCloudWinPE-$($ADKAMD64WinPEVersion)"
Write-Host -ForegroundColor Green "OSDCloud Template Name Set to: $TemplateName"

#Setup WorkSpace Location
Import-Module -name OSD -force
$OSDCloudWorkspace = "C:\OSDCloudWinPE-$($ADKAMD64WinPEVersion)"
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)
if (Test-Path -Path $OSDCloudWorkspace){
    Write-Host -ForegroundColor Green "Workspace Location Created: $OSDCloudWorkspace"
}

#New Template, this will create a new template based on the ADK WinPE version installed on the system
#This takes awhile, so be patient. It will take the winpe.wim from the ADK, apply all of the optional components
#It also will add 7Zip into the WinPE image, long with several other components uses by OSDCloud.
New-OSDCloudTemplate -Name $TemplateName -Add7Zip


#New WorkSpace
#This will create a new workspace based on the template created above.  This is very quick because it's just copying the template to the workspace location.
#Once it does the copy, you can make your edits to the workspace, most of which are done with Edit-OSDCloudWinPE.
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace
#Create the Setup Complete Templates that you can modify to have OSDCloud kick off your own custom script during Setup Complete.
New-OSDCloudWorkSpaceSetupCompleteTemplate

#Added HPCMSL into WinPE, USB Ethernet Drivers & HP WinPE DriverPack
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL -CloudDriver USB, HP
#After you run this, if you're going to use this for PXE or ISE, you do not need to create the USB drive.
#Instead of creating the USB drive, you can create a new ISO file that you can use for PXE or ISE.
New-OSDCloudISO -WorkspacePath $OSDCloudWorkspace
#You can now use that ISO to boot VM's or grab the contents for PXE.


#Create Cloud USB, which will be based on the workspace created above.
#This takes a little awhile and does the basic setup of the USB drive, including copying the WinPE image to the USB drive.
New-OSDCloudUSB

#Update the Cloud USB drive
#Note, I found I need to add some parameters for it to sync over everything properly.
Update-OSDCloudUSB -OSName 'Windows 11 24H2' -OSActivation Retail

#At this point, you should have a completely working OSDCloud USB Drive.