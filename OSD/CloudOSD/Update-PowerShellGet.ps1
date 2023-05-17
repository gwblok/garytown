<#  GARY BLOK - RecastSoftware.com @gwblok
2022.02.15

Update PowerShellGet and PackageManagement
#>

$WorkingDir = $env:TEMP

#PowerShellGet from PSGallery URL
if (!(Get-Module -Name PowerShellGet)){
    $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$WorkingDir\powershellget.2.2.5.zip"
    $Null = New-Item -Path "$WorkingDir\2.2.5" -ItemType Directory -Force
    Expand-Archive -Path "$WorkingDir\powershellget.2.2.5.zip" -DestinationPath "$WorkingDir\2.2.5"
    $Null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
    Move-Item -Path "$WorkingDir\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
    Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1" -Recurse -force
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
