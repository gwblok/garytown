<# GARY BLOK - GARYTOWN.COM @gwblok

This will leverage HPCMSL (Will install the module from gallery).
Then will install any SoftPaq you feed into the variable. 

There isn't much logging on this, you'll have to look at the endpoint logs for the install for any troubleshooting.

Thanks to OSDCloud for some of the functions


#>

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]$CMReboot = "FALSE",
            [Parameter(Mandatory=$true)][string]$RestartNow = "FALSE",
            [Parameter(Mandatory=$true)][string]$SoftPaqID
	    )


#$SoftPaqID = "sp111438"

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ManufacturerBaseBoard = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
if ($ManufacturerBaseBoard -eq "Intel Corporation")
    {
    $ComputerModel = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
$HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product

if ($Manufacturer -match "H*"){

    Function Start-InstallPackageManagement {
        [CmdletBinding()]
        param ()
        if ($WindowsPhase -eq 'WinPE') {
            $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
            if (-not $InstalledModule) {
                #Write-Host -ForegroundColor DarkGray 'Install PackageManagement'
                $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
                Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$env:TEMP\packagemanagement.1.4.7.zip"
                $null = New-Item -Path "$env:TEMP\1.4.7" -ItemType Directory -Force
                Expand-Archive -Path "$env:TEMP\packagemanagement.1.4.7.zip" -DestinationPath "$env:TEMP\1.4.7"
                $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
                Move-Item -Path "$env:TEMP\1.4.7" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.7"
                Import-Module PackageManagement -Force -Scope Global
            }
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
    Function Start-SetExecutionPolicy {
        [CmdletBinding()]
        param ()
        if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
            #Write-Host -ForegroundColor DarkGray 'Set-ExecutionPolicy RemoteSigned [CurrentUser]'
            Set-ExecutionPolicy RemoteSigned -Force -Scope CurrentUser
        }
    }
    Function Start-InstallPowerShellGet {
        [CmdletBinding()]
        param ()
        $InstalledModule = Import-Module PowerShellGet -PassThru -ErrorAction Ignore
        if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
            #Write-Host -ForegroundColor DarkGray 'Install PowerShellGet'
            $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
            Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$env:TEMP\powershellget.2.2.5.zip"
            $null = New-Item -Path "$env:TEMP\2.2.5" -ItemType Directory -Force
            Expand-Archive -Path "$env:TEMP\powershellget.2.2.5.zip" -DestinationPath "$env:TEMP\2.2.5"
            $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path "$env:TEMP\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
            Import-Module PowerShellGet -Force -Scope Global
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
    Function Start-InstallModuleHPCMSL {
        [CmdletBinding()]
        param ()
        Start-SetExecutionPolicy
        $InstallModule = $false
        $PSModuleName = 'HPCMSL'
        if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
            #Write-Host -ForegroundColor DarkGray 'Install-Package PackageManagement,PowerShellGet [AllUsers]'
            Install-Package -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Confirm:$false -Source PSGallery | Out-Null

            #Write-Host -ForegroundColor DarkGray 'Import-Module PackageManagement,PowerShellGet [Global]'
            Import-Module PackageManagement,PowerShellGet -Force -Scope Global -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            }
        $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
        $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

        if ($InstalledModule) {
            if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
                $InstallModule = $true
            }
        }
        else {
            $InstallModule = $true
        }

        if ($InstallModule) {
            if ($WindowsPhase -eq 'WinPE') {
                #Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Install-Module $PSModuleName -SkipPublisherCheck -Scope AllUsers -Force -AcceptLicense -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            else {
                #Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Install-Module $PSModuleName -SkipPublisherCheck -AcceptLicense -Scope AllUsers -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
        }
        Import-Module -Name $PSModuleName -Force -Global -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    Function Restart-ComputerCM {
        if (Test-Path -Path "C:\windows\ccm\CcmRestart.exe"){

            $time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
            $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;

            $CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
        }
        else {
            Write-Output "No CM Client Found"
        }
    }
    
    Start-InstallPackageManagement
    Start-InstallPowerShellGet
    Start-TrustPSGallery
    Start-InstallModuleHPCMSL

    $MetaData = Get-SoftpaqMetadata -Number $SoftPaqID
    $Version = $MetaData.General.Version
    $Category = $MetaData.General.Category
    $VendorName = $MetaData.General.VendorName
    $VendorVersion = $MetaData.General.VendorVersion

    Write-Output "$HPProdCode | $ComputerModel | Installing $SoftPaqID | $Category  $Version | Vendor: $VendorName $VendorVersion"
    $Install = Get-Softpaq -Number $SoftPaqID -Quiet -Action silentinstall -Overwrite skip
    if ($CMReboot -eq "TRUE"){Restart-ComputerCM}
    if ($RestartNow -eq "TRUE") {Restart-Computer -Force}
}
