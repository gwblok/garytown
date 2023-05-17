<#  GARY BLOK - GARYTOWN.com @gwblok
2023.01.11

This script will set the LOCALAPPDATA Variable and install PowerShellGet & PackageManagement from the PowerShell Gallery via Invoke-WebRequest.
Once installed and working, then it will leverage the PSGallery to install other Modules that are specified as the 'ModuleName' Parameter.

This Script will Setup WinPE with PowerShellGet & PackageManagement
It's possible you'll need to run it twice so that the new versions are in effect.

This script will also attempt to load the modules into the offline OS (Assuming it's the C: Drive).

Anytime you want to install something from the gallery while in WinPE, you'll need to set the LOCALAPPDATA Variable as it is below.

powershell.exe -executionpolicy bypass -command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Install-PSModules_WinPE.ps1')"
#>

$ModuleName = "HPCMSL"  #Change the Module Name if you want to install something else.

Write-Host "Settins Local Appdata Varaiable"
#Setup LOCALAPPDATA Variable
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")

$WorkingDir = $env:TEMP

Write-Host "PowerShellGet from PSGallery URL"
#PowerShellGet from PSGallery URL
if (!(Get-Module -Name PowerShellGet)){
    if (!(Test-Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5")){
        $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$WorkingDir\powershellget.2.2.5.zip"
        $Null = New-Item -Path "$WorkingDir\2.2.5" -ItemType Directory -Force
        Expand-Archive -Path "$WorkingDir\powershellget.2.2.5.zip" -DestinationPath "$WorkingDir\2.2.5"
        $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$WorkingDir\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
        if (Test-Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1"){
            Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1" -Recurse -force
        }
    }
}
if (Test-Path "C:\Program Files\WindowsPowerShell\Modules"){
    if (Test-Path -Path "C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1"){
        Remove-Item "C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1" -Recurse
    }
    Copy-Item  "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5" -Destination "C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\2.2.5" -Recurse -Force
}
Write-Host "PackageManagement from PSGallery URL"
#PackageManagement from PSGallery URL
if (!(Get-Module -Name PackageManagement)){
    if (!(Test-Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7")){
        $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$WorkingDir\packagemanagement.1.4.7.zip"
        $Null = New-Item -Path "$WorkingDir\1.4.7" -ItemType Directory -Force
        Expand-Archive -Path "$WorkingDir\packagemanagement.1.4.7.zip" -DestinationPath "$WorkingDir\1.4.7"
        $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$WorkingDir\1.4.7" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7"
    }
}
if (Test-Path "C:\Program Files\WindowsPowerShell\Modules"){
    if (Test-Path -Path "C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.0.0.1"){
        Remove-Item "C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.0.0.1" -Recurse
    }
     Copy-Item  "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7" -Destination "C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.4.7" -Recurse -Force
}

Write-Host "Import-Module PowerShellGet -RequiredVersion 2.2.5 -Force"
#Import PowerShellGet
Import-Module PowerShellGet -RequiredVersion 2.2.5 -Force

Write-Host "Installing $ModuleName"
#Install Module from PSGallery
if ($ModuleName -eq "HPCMSL"){
    Install-Module -Name $ModuleName -Force -AcceptLicense -SkipPublisherCheck
    if (Test-Path "C:\Program Files\WindowsPowerShell\Modules"){
        Save-Module -Name $ModuleName -Path "C:\Program Files\WindowsPowerShell\Modules" -AcceptLicense
    }
}
else {
    Install-Module -Name $ModuleName -Force -SkipPublisherCheck
    if (Test-Path "C:\Program Files\WindowsPowerShell\Modules"){
        Save-Module -Name $ModuleName -Path "C:\Program Files\WindowsPowerShell\Modules"
    }
}
Write-Host "Import-Module -Name $ModuleName -Force"
Import-Module -Name $ModuleName -Force



