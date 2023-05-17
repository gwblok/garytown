Function Start-InstallPackageManagement {
    [CmdletBinding()]
    param ()
    $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
    if (-not ($InstalledModule.Version -ge "1.4.7")) {
        #Write-Host -ForegroundColor DarkGray 'Install PackageManagement'
        $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$env:windir\packagemanagement.1.4.7.zip"
        $null = New-Item -Path "$env:windir\1.4.7" -ItemType Directory -Force
        Expand-Archive -Path "$env:windir\packagemanagement.1.4.7.zip" -DestinationPath "$env:windir\1.4.7"
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:windir\1.4.7" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7"
        Import-Module PackageManagement -Force -Scope Global
    }
    else {
        if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
            #Write-Host -ForegroundColor DarkGray 'Install-Package PackageManagement,PowerShellGet [AllUsers]'
            Install-Package -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Confirm:$false -Source PSGallery | Out-Null
    
            #Write-Host -ForegroundColor DarkGray 'Import-Module PackageManagement,PowerShellGet [Global]'
            Import-Module PackageManagement,PowerShellGet -Force -Scope Global
        }
    }
}
Function Start-InstallPowerShellGet {
    [CmdletBinding()]
    param ()
    $InstalledModule = Import-Module PowerShellGet -PassThru -ErrorAction Ignore
    if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
        #Write-Host -ForegroundColor DarkGray 'Install PowerShellGet'
        $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$env:windir\powershellget.2.2.5.zip"
        $null = New-Item -Path "$env:windir\2.2.5" -ItemType Directory -Force
        Expand-Archive -Path "$env:windir\powershellget.2.2.5.zip" -DestinationPath "$env:windir\2.2.5" -Force
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:windir\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
        Import-Module PowerShellGet -Force -Scope Global
    }
}
Function Start-InstallNuGet {
    [CmdletBinding()]
    param ()
    if (-not (Get-PackageProvider -Name "NuGet" -ListAvailable | Where-Object {$_.Version -ge '2.8.5.208'})) {
        Install-PackageProvider -Name "NuGet" -Force
    }
}
Function Start-TrustPSGallery {
    [CmdletBinding()]
    param ()
    $PSRepository = Get-PSRepository -Name PSGallery
    if ($PSRepository) {
            if ($PSRepository.InstallationPolicy -ne 'Trusted') {
                #Write-Host -ForegroundColor DarkGray 'Set-PSRepository PSGallery Trusted [CurrentUser]'
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
        }
}
Start-InstallNuGet
Start-InstallPackageManagement
Start-TrustPSGallery
Start-InstallPowerShellGet


install-module -name "SQLServer"
$Primary_SizeDB = "256MB"
$Primary_MaxSizeDB = "1024MB"
$Primary_FileGrowth = "64MB"

$FG_SizeDB = "256MB"
$FG_MaxSizeDB = "10240MB"
$FG_FileGrowth = "256MB"

$Log_SizeDB = "16MB"
$Log_MaxSizeDB = "256MB"
$Log_FileGrowth = "4MB"

$DBName = "CM_MCM"
$DBPath = "D:\SQL\DB"
$LogPath = "D:\SQL\LOG"

$sql = "
USE master;
GO

CREATE DATABASE $DBName
ON PRIMARY
  ( NAME = '$($DBName)_PRI',
    FILENAME = '$DBPath\$($DBName)_PRI.mdf',
    SIZE = $Primary_SizeDB,
    MAXSIZE=$Primary_MaxSizeDB,
    FILEGROWTH=$Primary_FileGrowth),
FILEGROUP FG_$($DBName)
  ( NAME = '$($DBName)_FG_1',
    FILENAME = '$DBPath\$($DBName)_FG1_1.mdf',
    SIZE = $FG_SizeDB,
    MAXSIZE=$FG_MaxSizeDB,
    FILEGROWTH=$FG_FileGrowth),
  ( NAME = '$($DBName)_FG_2',
    FILENAME = '$DBPath\$($DBName)_FG1_2.mdf',
    SIZE = $FG_SizeDB,
    MAXSIZE=$FG_MaxSizeDB,
    FILEGROWTH=$FG_FileGrowth),
  ( NAME = '$($DBName)_FG_3',
    FILENAME = '$DBPath\$($DBName)_FG1_3.mdf',
    SIZE = $FG_SizeDB,
    MAXSIZE=$FG_MaxSizeDB,
    FILEGROWTH=$FG_FileGrowth),
  ( NAME = '$($DBName)_FG_4',
    FILENAME = '$DBPath\$($DBName)_FG1_4.mdf',
    SIZE = $FG_SizeDB,
    MAXSIZE=$FG_MaxSizeDB,
    FILEGROWTH=$FG_FileGrowth)
LOG ON
  ( NAME='$($DBName)_log',
    FILENAME = '$LogPath\$($DBName)_Log.ldf',
    SIZE=$Log_SizeDB,
    MAXSIZE=$Log_MaxSizeDB,
    FILEGROWTH=$Log_FileGrowth);
GO
ALTER DATABASE $($DBName)
  MODIFY FILEGROUP FG_$($DBName) DEFAULT;
GO
ALTER DATABASE $($DBName)
SET RECOVERY SIMPLE
GO
"

Invoke-Sqlcmd $sql
