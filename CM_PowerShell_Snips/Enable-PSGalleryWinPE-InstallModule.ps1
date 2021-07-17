<#  GARY BLOK - RecastSoftware.com @gwblok
2021.07.17

This script will set the LOCALAPPDATA Variable and install PowerShellGet & PackageManagement from the PowerShell Gallery via Invoke-WebRequest.
Once installed and working, then it will leverage the PSGallery to install other Modules that are specified as the 'ModuleName' Parameter.

Enable-PSGalleryWinPE-InstallModule.ps1 -ModuleName "HPCMSL"

Note, I've only tested with Modules HPCMSL & OSDSUS.  If you run into issues, consider changing the Install-Module line.

Troubleshooting - Boot your WinPE ConfigMgr Image with F8 Support Enabled, Press F8 for Command Prompt, copy script local, run script and do your normal troubleshooting
This has NOT been tested with Proxies, if you have Proxies, you'll need to update the script to accomidate.

YouTube Video of Script in action as described in the Troubleshooting Method: https://www.youtube.com/watch?v=YXykIY6nIa8
More Info: https://github.com/recast-software/ConfigMgr-Docs/blob/main/TaskSequence/WinPE_PSGallery.md

#>

param (
    [string]$ModuleName
)

#Setup LOCALAPPDATA Variable
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")

$WorkingDir = $env:TEMP

#PowerShellGet from PSGallery URL
if (!(Get-Module -Name PowerShellGet)){
    $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$WorkingDir\powershellget.2.2.5.zip"
    $Null = New-Item -Path "$WorkingDir\2.2.5" -ItemType Directory -Force
    Expand-Archive -Path "$WorkingDir\powershellget.2.2.5.zip" -DestinationPath "$WorkingDir\2.2.5"
    $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
    Move-Item -Path "$WorkingDir\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
    }

#PackageManagement from PSGallery URL
if (!(Get-Module -Name PackageManagement)){
    $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$WorkingDir\packagemanagement.1.4.7.zip"
    $Null = New-Item -Path "$WorkingDir\1.4.7" -ItemType Directory -Force
    Expand-Archive -Path "$WorkingDir\packagemanagement.1.4.7.zip" -DestinationPath "$WorkingDir\1.4.7"
    $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
    Move-Item -Path "$WorkingDir\1.4.7" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7"
    }

#Import PowerShellGet
Import-Module PowerShellGet


#Install Module from PSGallery
Install-Module -Name $ModuleName -Force -AcceptLicense -SkipPublisherCheck
Import-Module -Name $ModuleName -Force
