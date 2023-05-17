<#PSScriptInfo
.VERSION 22.5.18.1
.GUID 7a3671f6-485b-443e-8e86-b60fdcea1419
.AUTHOR David Segura @SeguraOSD
.COMPANYNAME osdcloud.com
.COPYRIGHT (c) 2022 David Segura osdcloud.com. All rights reserved.
.TAGS OSDeploy OSDCloud WinPE OOBE Windows AutoPilot
.LICENSEURI 
.PROJECTURI https://github.com/OSDeploy/OSD
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
Script should be executed in a Command Prompt using the following command
powershell Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)
This is abbreviated as
powershell iex (irm functions.osdcloud.com)
#>
<#
.SYNOPSIS
    PSCloudScript at functions.osdcloud.com
.DESCRIPTION
    PSCloudScript at functions.osdcloud.com
.NOTES
    Version 22.5.19.5
.LINK
    https://raw.githubusercontent.com/OSDeploy/OSD/master/cloudscript/functions.osdcloud.com.ps1
.EXAMPLE
    powershell iex (irm functions.osdcloud.com)
#>
#=================================================
#Script Information
$ScriptName = 'functions.osdcloud.com'
$ScriptVersion = '22.5.19.5'
#=================================================
#region Initialize Functions
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

#Determine the proper Windows environment
if ($env:SystemDrive -eq 'X:') {$WindowsPhase = 'WinPE'}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}
$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
if ($Manufacturer -match "HP" -or $Manufacturer -match "Hewlett-Packard"){$Manufacturer = "HP"}
if ($Manufacturer -match "Dell"){$Manufacturer = "Dell"}

#Finish Initialization
Write-Host -ForegroundColor DarkGray "$ScriptName $ScriptVersion $WindowsPhase"

#endregion
#=================================================
#region Environment Variables
$oobePowerShellProfile = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
[System.Environment]::SetEnvironmentVariable('Path',$Env:Path + ";$Env:ProgramFiles\WindowsPowerShell\Scripts",'Process')
'@
$winpePowerShellProfile = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
[System.Environment]::SetEnvironmentVariable('APPDATA',"$Env:UserProfile\AppData\Roaming",[System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable('HOMEDRIVE',"$Env:SystemDrive",[System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable('HOMEPATH',"$Env:UserProfile",[System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$Env:UserProfile\AppData\Local",[System.EnvironmentVariableTarget]::Process)
'@
#endregion
#=================================================
#region PowerShell Prompt
<#
Since these functions are temporarily loaded, the PowerShell Prompt is changed to make it visual if the functions are loaded or not
[OSDCloud]: PS C:\>

You can read more about how to make the change here
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts?view=powershell-5.1
#>
function Prompt {
    $(if (Test-Path variable:/PSDebugContext) { '[DBG]: ' }
    else { "[OSDCloud]: " }
    ) + 'PS ' + $(Get-Location) +
    $(if ($NestedPromptLevel -ge 1) { '>>' }) + '> '
}
#endregion
#=================================================
#region WinPE Functions
if ($WindowsPhase -eq 'WinPE') {
    function osdcloud-InstallCurl {
        [CmdletBinding()]
        param ()
        if (-not (Get-Command 'curl.exe' -ErrorAction SilentlyContinue)) {
            Write-Host -ForegroundColor DarkGray 'Install Curl'
            $Uri = 'https://curl.se/windows/dl-7.81.0/curl-7.81.0-win64-mingw.zip'
            Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile "$env:TEMP\curl.zip"
    
            $null = New-Item -Path "$env:TEMP\Curl" -ItemType Directory -Force
            Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl"
    
            Get-ChildItem "$env:TEMP\curl" -Include 'curl.exe' -Recurse | foreach {Copy-Item $_ -Destination "$env:SystemRoot\System32\curl.exe"}
        }
    }
    function osdcloud-InstallNuget {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor DarkGray 'Install Nuget'
        $NuGetClientSourceURL = 'https://nuget.org/nuget.exe'
        $NuGetExeName = 'NuGet.exe'
    
        $PSGetProgramDataPath = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetProgramDataPath
        if (-not (Test-Path -Path $nugetExeBasePath))
        {
            $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
    
        $PSGetAppLocalPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetAppLocalPath
    
        if (-not (Test-Path -Path $nugetExeBasePath))
        {
            $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
    }
    function osdcloud-InstallPowerShellGet {
        [CmdletBinding()]
        param ()
        $InstalledModule = Import-Module PowerShellGet -PassThru -ErrorAction Ignore
        if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
            #Write-Host -ForegroundColor DarkGray 'Import-Module PackageManagement,PowerShellGet [Global]'
            #Import-Module PackageManagement,PowerShellGet -Force -Scope Global
            Write-Host -ForegroundColor DarkGray 'Install PowerShellGet'
            $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
            Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$env:TEMP\powershellget.2.2.5.zip"
            $null = New-Item -Path "$env:TEMP\2.2.5" -ItemType Directory -Force
            Expand-Archive -Path "$env:TEMP\powershellget.2.2.5.zip" -DestinationPath "$env:TEMP\2.2.5"
            $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path "$env:TEMP\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
            Import-Module PowerShellGet -Force -Scope Global
        }
    }
    function osdcloud-SetEnvironmentVariables {
        [CmdletBinding()]
        param ()
        if (Get-Item env:LocalAppData -ErrorAction Ignore) {
            Write-Verbose 'System Environment Variable LocalAppData is already present in this PowerShell session'
        }
        else {
            Write-Host -ForegroundColor DarkGray 'Set LocalAppData in System Environment'
            Write-Verbose 'WinPE does not have the LocalAppData System Environment Variable'
            Write-Verbose 'This can be enabled for this Power Session, but it will not persist'
            Write-Verbose 'Set System Environment Variable LocalAppData for this PowerShell session'
            #[System.Environment]::SetEnvironmentVariable('LocalAppData',"$env:UserProfile\AppData\Local")
            [System.Environment]::SetEnvironmentVariable('APPDATA',"$Env:UserProfile\AppData\Roaming",[System.EnvironmentVariableTarget]::Process)
            [System.Environment]::SetEnvironmentVariable('HOMEDRIVE',"$Env:SystemDrive",[System.EnvironmentVariableTarget]::Process)
            [System.Environment]::SetEnvironmentVariable('HOMEPATH',"$Env:UserProfile",[System.EnvironmentVariableTarget]::Process)
            [System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$Env:UserProfile\AppData\Local",[System.EnvironmentVariableTarget]::Process)
        }
    }
    function AzOSD {
        [CmdletBinding()]
        param ()
        Connect-AzOSDCloud
        Get-AzOSDCloudBlobImage
        Start-AzOSDCloud
    }
}
#endregion
#=================================================
#region WinPE OOBE Functions
if (($WindowsPhase -eq 'WinPE') -or ($WindowsPhase -eq 'OOBE')) {
    function osdcloud-RemoveAppx {
        [CmdletBinding(DefaultParameterSetName='Default')]
        param (
            [Parameter(Mandatory,ParameterSetName='Basic')]
            [System.Management.Automation.SwitchParameter]$Basic,
    
            [Parameter(Mandatory,ParameterSetName='ByName',Position=0)]
            [System.String[]]$Name
        )
        if ($WindowsPhase -eq 'WinPE') {
            if (Get-Command Get-AppxProvisionedPackage) {
                if ($Basic) {
                    $Name = @('CommunicationsApps','OfficeHub','People','Skype','Solitaire','Xbox','ZuneMusic','ZuneVideo')
                }
                elseif ($Name) {
                    #Do Nothing
                }
                if ($Name) {
                    Write-Host -ForegroundColor Cyan "Remove-AppxProvisionedPackage -Path 'C:\' -PackageName"
                    foreach ($Item in $Name) {
                        Get-AppxProvisionedPackage -Path 'C:\' | Where-Object {$_.DisplayName -Match $Item} | ForEach-Object {
                            Write-Host -ForegroundColor DarkGray $_.DisplayName
                            Try {
                                $null = Remove-AppxProvisionedPackage -Path 'C:\' -PackageName $_.PackageName
                            }
                            Catch {
                                Write-Warning "Appx Provisioned Package $($_.PackageName) did not remove successfully"
                            }
                        }
                    }
                }
            }
        }
        if ($WindowsPhase -eq 'OOBE') {
            if (Get-Command Get-AppxProvisionedPackage) {
                if ($Basic) {
                    $Name = @('CommunicationsApps','OfficeHub','People','Skype','Solitaire','Xbox','ZuneMusic','ZuneVideo')
                }
                elseif ($Name) {
                    #Do Nothing
                }
                else {
                    $Name = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | `
                    Select-Object -Property DisplayName, PackageName | `
                    Out-GridView -PassThru -Title 'Select one or more Appx Provisioned Packages to remove' | `
                    Select-Object -ExpandProperty DisplayName
                }
                if ($Name) {
                    Write-Host -ForegroundColor Cyan 'Remove-AppxProvisionedPackage -Online -AllUsers -PackageName'
                    foreach ($Item in $Name) {
                        Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -Match $Item} | ForEach-Object {
                            Write-Host -ForegroundColor DarkGray $_.DisplayName
                            if ((Get-Command Remove-AppxProvisionedPackage).Parameters.ContainsKey('AllUsers')) {
                                Try {
                                    $null = Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $_.PackageName
                                }
                                Catch {
                                    Write-Warning "AllUsers Appx Provisioned Package $($_.PackageName) did not remove successfully"
                                }
                            }
                            else {
                                Try {
                                    $null = Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName
                                }
                                Catch {
                                    Write-Warning "Appx Provisioned Package $($_.PackageName) did not remove successfully"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    New-Alias -Name 'RemoveAppx' -Value 'osdcloud-RemoveAppx' -Description 'OSDCloud' -Force
    function osdcloud-SetPowerShellProfile {
        [CmdletBinding()]
        param ()
        if ($WindowsPhase -eq 'WinPE') {
            if (-not (Test-Path "$env:UserProfile\Documents\WindowsPowerShell")) {
                $null = New-Item -Path "$env:UserProfile\Documents\WindowsPowerShell" -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor DarkGray 'Set LocalAppData in PowerShell Profile'
            $winpePowerShellProfile | Set-Content -Path "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force -Encoding Unicode
        }
        if ($WindowsPhase -eq 'OOBE') {
            if (-not (Test-Path $Profile.CurrentUserAllHosts)) {
                
                Write-Host -ForegroundColor DarkGray 'Set PowerShell Profile [CurrentUserAllHosts]'
                $null = New-Item $Profile.CurrentUserAllHosts -ItemType File -Force
    
                #[System.Environment]::SetEnvironmentVariable('Path',"$Env:LocalAppData\Microsoft\WindowsApps;$Env:ProgramFiles\WindowsPowerShell\Scripts;",'User')
    
                #[System.Environment]::SetEnvironmentVariable('Path',$Env:Path + ";$Env:ProgramFiles\WindowsPowerShell\Scripts")
                #[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
    
                $oobePowerShellProfile | Set-Content -Path $Profile.CurrentUserAllHosts -Force -Encoding Unicode
            }
        }
    }
    function osdcloud-TrustPSGallery {
        [CmdletBinding()]
        param ()
        if ($WindowsPhase -eq 'WinPE') {
            $PSRepository = Get-PSRepository -Name PSGallery
            if ($PSRepository) {
                if ($PSRepository.InstallationPolicy -ne 'Trusted') {
                    Write-Host -ForegroundColor DarkGray 'Set-PSRepository PSGallery Trusted'
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                }
            }
        }
        if ($WindowsPhase -eq 'OOBE') {
            $PSRepository = Get-PSRepository -Name PSGallery
            if ($PSRepository) {
                if ($PSRepository.InstallationPolicy -ne 'Trusted') {
                    Write-Host -ForegroundColor DarkGray 'Set-PSRepository PSGallery Trusted [CurrentUser]'
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                }
            }
        }
    }
    function osdcloud-GetKeyVaultSecretList {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true, Position=0)]
            [System.String]
            # Specifies the name of the key vault to which the secret belongs. This cmdlet constructs the fully qualified domain name (FQDN) of a key vault based on the name that this parameter specifies and your current environment.
            $VaultName
        )
        $Module = Import-Module Az.Accounts -PassThru -ErrorAction Ignore
        if (-not $Module) {
            Install-Module Az.Accounts -Force
        }
        
        $Module = Import-Module Az.KeyVault -PassThru -ErrorAction Ignore
        if (-not $Module) {
            Install-Module Az.KeyVault -Force
        }
    
        if (!(Get-AzContext -ErrorAction Ignore)) {
            Connect-AzAccount -DeviceCode
        }

        if (Get-AzContext -ErrorAction Ignore) {
            Get-AzKeyVaultSecret -VaultName "$VaultName" | Select-Object -ExpandProperty Name
        }
        else {
            Write-Error "Authenticate to Azure using 'Connect-AzAccount -DeviceCode'"
        }
    }
    New-Alias -Name 'ListSecrets' -Value 'osdcloud-GetKeyVaultSecretList' -Description 'OSDCloud' -Force
    function osdcloud-InvokeKeyVaultSecret {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true, Position=0)]
            [System.String]
            # Specifies the name of the key vault to which the secret belongs. This cmdlet constructs the fully qualified domain name (FQDN) of a key vault based on the name that this parameter specifies and your current environment.
            $VaultName,

            [Parameter(Mandatory=$true, Position=1)]
            [System.String]
            # Specifies the name of the secret to get the content to use as a PSCloudScript
            $Name
        )
        $Module = Import-Module Az.Accounts -PassThru -ErrorAction Ignore
        if (-not $Module) {
            Install-Module Az.Accounts -Force
        }
        
        $Module = Import-Module Az.KeyVault -PassThru -ErrorAction Ignore
        if (-not $Module) {
            Install-Module Az.KeyVault -Force
        }
    
        if (!(Get-AzContext -ErrorAction Ignore)) {
            Connect-AzAccount -DeviceCode
        }

        if (Get-AzContext -ErrorAction Ignore) {
            $Result = Get-AzKeyVaultSecret -VaultName "$VaultName" -Name "$Name" -AsPlainText
            if ($Result) {
                Invoke-Expression -Command $Result
            }
        }
        else {
            Write-Error "Authenticate to Azure using 'Connect-AzAccount -DeviceCode'"
        }
    }
    New-Alias -Name 'InvokeSecret' -Value 'osdcloud-InvokeKeyVaultSecret' -Description 'OSDCloud' -Force
}
#endregion
#=================================================
#region OOBE Functions
if ($WindowsPhase -eq 'OOBE') {
    function osdcloud-SetWindowsDateTime {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor Yellow 'Verify the Date and Time is set properly including the Time Zone'
        Write-Host -ForegroundColor Yellow 'If this is not configured properly, Certificates and Domain Join may fail'
        Start-Process 'ms-settings:dateandtime' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
    function osdcloud-SetWindowsDisplay {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor Yellow 'Verify the Display Resolution and Scale is set properly'
        Start-Process 'ms-settings:display' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
    function osdcloud-SetWindowsLanguage {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor Yellow 'Verify the Language, Region, and Keyboard are set properly'
        Start-Process 'ms-settings:regionlanguage' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
    function osdcloud-AutopilotRegisterCommand {
        [CmdletBinding()]
        param (
            [System.String]
            $Command = 'Get-WindowsAutopilotInfo -Online -Assign'
        )
        Write-Host -ForegroundColor Cyan 'Registering Device in Autopilot in new PowerShell window ' -NoNewline
        $AutopilotProcess = Start-Process PowerShell.exe -ArgumentList "-Command $Command" -PassThru
        Write-Host -ForegroundColor Green "(Process Id $($AutopilotProcess.Id))"
        Return $AutopilotProcess
    }
    function osdcloud-AddCapability {
        [CmdletBinding(DefaultParameterSetName='Default')]
        param (
            [Parameter(Mandatory,ParameterSetName='ByName',Position=0)]
            [System.String[]]$Name
        )
        if ($Name) {
            #Do Nothing
        }
        else {
            $Name = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'} | Select-Object Name | Out-GridView -PassThru -Title 'Select one or more Capabilities' | Select-Object -ExpandProperty Name
        }
        if ($Name) {
            Write-Host -ForegroundColor Cyan "Add-WindowsCapability -Online"
            foreach ($Item in $Name) {
                $WindowsCapability = Get-WindowsCapability -Online -Name "*$Item*" -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'}
                if ($WindowsCapability) {
                    foreach ($Capability in $WindowsCapability) {
                        Write-Host -ForegroundColor DarkGray $Capability.DisplayName
                        $Capability | Add-WindowsCapability -Online | Out-Null
                    }
                }
            }
        }
    }
    New-Alias -Name 'AddCapability' -Value 'osdcloud-AddCapability' -Description 'OSDCloud' -Force
    function osdcloud-NetFX {
        [CmdletBinding()]
        param ()
        $WindowsCapability = Get-WindowsCapability -Online -Name "*NetFX*" -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'}
        if ($WindowsCapability) {
            Write-Host -ForegroundColor Cyan "Add-WindowsCapability NetFX"
            foreach ($Capability in $WindowsCapability) {
                Write-Host -ForegroundColor DarkGray $Capability.DisplayName
                $Capability | Add-WindowsCapability -Online | Out-Null
            }
        }
    }
    New-Alias -Name 'NetFX' -Value 'osdcloud-NetFX' -Description 'OSDCloud' -Force
    function osdcloud-Rsat {
        [CmdletBinding(DefaultParameterSetName='Default')]
        param (
            [Parameter(Mandatory,ParameterSetName='Basic')]
            [System.Management.Automation.SwitchParameter]$Basic,
    
            [Parameter(Mandatory,ParameterSetName='Full')]
            [System.Management.Automation.SwitchParameter]$Full,
    
            [Parameter(Mandatory,ParameterSetName='ByName',Position=0)]
            [System.String[]]$Name
        )
        if ($Basic) {
            $Name = @('ActiveDirectory','BitLocker','GroupPolicy','RemoteDesktop','VolumeActivation')
        }
        elseif ($Full) {
            $Name = 'Rsat'
        }
        elseif ($Name) {
            #Do Nothing
        }
        else {
            $Name = Get-WindowsCapability -Online -Name "*Rsat*" -ErrorAction SilentlyContinue | `
            Where-Object {$_.State -ne 'Installed'} | `
            Select-Object Name, DisplayName, Description | `
            Out-GridView -PassThru -Title 'Select one or more Rsat Capabilities to install' | `
            Select-Object -ExpandProperty Name
        }
        if ($Name) {
            Write-Host -ForegroundColor Cyan "Add-WindowsCapability -Online Rsat"
            foreach ($Item in $Name) {
                $WindowsCapability = Get-WindowsCapability -Online -Name "*$Item*" -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'}
                if ($WindowsCapability) {
                    foreach ($Capability in $WindowsCapability) {
                        Write-Host -ForegroundColor DarkGray $Capability.DisplayName
                        $Capability | Add-WindowsCapability -Online | Out-Null
                    }
                }
            }
        }
    }
    New-Alias -Name 'Rsat' -Value 'osdcloud-Rsat' -Description 'OSDCloud' -Force
    function osdcloud-UpdateDrivers {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor Cyan 'Updating Windows Drivers in a minimized window'
        if (!(Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore)) {
            try {
                Install-Module PSWindowsUpdate -Force -Scope CurrentUser
                Import-Module PSWindowsUpdate -Force -Scope Global
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Driver Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            Start-Process -WindowStyle Minimized PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot" -Wait
        }
    }
    New-Alias -Name 'UpdateDrivers' -Value 'osdcloud-UpdateDrivers' -Description 'OSDCloud' -Force
    function osdcloud-UpdateWindows {
        [CmdletBinding()]
        param ()
        Write-Host -ForegroundColor Cyan 'Updating Windows in a minimized window'
        if (!(Get-Module PSWindowsUpdate -ListAvailable)) {
            try {
                Install-Module PSWindowsUpdate -Force -Scope CurrentUser
                Import-Module PSWindowsUpdate -Force -Scope Global
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Windows Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            #Write-Host -ForegroundColor DarkGray 'Add-WUServiceManager -MicrosoftUpdate -Confirm:$false'
            Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
            #Write-Host -ForegroundColor DarkGray 'Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot'
            #Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot -NotTitle 'Malicious'
            #Write-Host -ForegroundColor DarkGray 'Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot'
            Start-Process -WindowStyle Minimized PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -NotTitle 'Preview' -NotKBArticleID 'KB890830','KB5005463','KB4481252'" -Wait
        }
    }
    New-Alias -Name 'UpdateWindows' -Value 'osdcloud-UpdateWindows' -Description 'OSDCloud' -Force
    function osdcloud-UpdateDefender {
        [CmdletBinding()]
        param ()
        if (Test-Path "$env:ProgramFiles\Windows Defender\MpCmdRun.exe") {
            Write-Host -ForegroundColor Cyan 'Updating Windows Defender'
            & "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -signatureupdate
        }
    }
    New-Alias -Name 'UpdateDefender' -Value 'osdcloud-UpdateDefender' -Description 'OSDCloud' -Force
    function osdcloud-UpdateDefenderStack {
        [CmdletBinding()]
        param ()
        # Source Addresses - Defender for Windows 10, 8.1 ################################
        $sourceAVx64 = "http://go.microsoft.com/fwlink/?LinkID=121721&arch=x64"
        $sourceNISx64 = "http://go.microsoft.com/fwlink/?LinkID=187316&arch=x64&nri=true"
        $sourcePlatformx64 = "https://go.microsoft.com/fwlink/?LinkID=870379&clcid=0x409&arch=x64"

        # Web client #####################################################################
        Write-Output "UPDATE Defender Package Script version $ScriptVer..."
        # Prepare Intermediate folder ###################################################

        $Intermediate = "$env:TEMP\DefenderScratchSpace"

        if(!(Test-Path -Path "$Intermediate")) {
            $Null = New-Item -Path "$env:TEMP" -Name "DefenderScratchSpace" -ItemType Directory
            }

        if(!(Test-Path -Path "$Intermediate\x64")) {
            $Null = New-Item -Path "$Intermediate" -Name "x64" -ItemType Directory
            }
        Remove-Item -Path "$Intermediate\x64\*" -Force -EA SilentlyContinue
        $wc = New-Object System.Net.WebClient

        # x64 AV #########################################################################

        $Dest = "$Intermediate\x64\" + 'mpam-fe.exe'
        Write-Output "Starting MPAM-FE Download"
        $wc.DownloadFile($sourceAVx64, $Dest)
        if(Test-Path -Path $Dest) {
            $x = Get-Item -Path $Dest
            [version]$Version1a = $x.VersionInfo.ProductVersion #Downloaded
            [version]$Version1b = (Get-MpComputerStatus).AntivirusSignatureVersion #Currently Installed
            if ($Version1a -gt $Version1b){
                Write-Output "Starting MPAM-FE Install of $Version1b to $Version1a"
                $MPAMInstall = Start-Process -FilePath $Dest -Wait -PassThru
                }
            else{Write-Output "No Update Needed, Installed:$Version1b vs Downloaded: $Version1a"}
            Write-Output "Finished MPAM-FE Install"
            }
        else{Write-Output "Failed MPAM-FE Download"}
        # x64 Update Platform ########################################################################
        Write-Output "Starting Update Platform Download"
        $Dest = "$Intermediate\x64\" + 'UpdatePlatform.exe'
        $wc.DownloadFile($sourcePlatformx64, $Dest)

        if(Test-Path -Path $Dest) {
            $x = Get-Item -Path $Dest
            [version]$Version2a = $x.VersionInfo.ProductVersion #Downloaded
            [version]$Version2b = (Get-MpComputerStatus).AMServiceVersion #Installed

            if ($Version2a -gt $Version2b){
                Write-Output "Starting Update Platform Install of $Version2b to $Version2a"
                $UPInstall = Start-Process -FilePath $Dest -Wait -PassThru
                }
            else {Write-Output "No Update Needed, Installed:$Version2b vs Downloaded: $Version2a"}
            Write-Output "Finished Update Platform Install"
            }
        else {Write-Output "Failed Update Platform Download"}
        }
}
#endregion
#=================================================
#region Anywhere Functions

function osdcloud-EjectCD {
    [CmdletBinding()]
    param ()   
    (New-Object -ComObject 'Shell.Application').Namespace(17).Items() | Where-Object { $_.Type -eq 'CD Drive' } | ForEach-Object { $_.InvokeVerb('Eject') }
    }  
function osdcloud-InstallModuleHPCMSL {
    [CmdletBinding()]
    param ()
    $InstallModule = $false
    $PSModuleName = 'HPCMSL'
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
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -SkipPublisherCheck -Scope AllUsers -Force -AcceptLicense
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -SkipPublisherCheck -AcceptLicense -Scope AllUsers -Force
        }
    }
    Import-Module -Name $PSModuleName -Force -Global -ErrorAction SilentlyContinue
}
function osdcloud-DetermineHPTPM{
    $SP87753 = Get-CimInstance  -Namespace "root\cimv2\security\MicrosoftTPM" -query "select * from win32_tpm where IsEnabled_InitialValue = 'True' and ((ManufacturerVersion like '7.%' and ManufacturerVersion < '7.63.3353') or (ManufacturerVersion like '5.1%') or (ManufacturerVersion like '5.60%') or (ManufacturerVersion like '5.61%') or (ManufacturerVersion like '4.4%') or (ManufacturerVersion like '6.40%') or (ManufacturerVersion like '6.41%') or (ManufacturerVersion like '6.43.243.0') or (ManufacturerVersion like '6.43.244.0'))"
    $SP94937 = Get-CimInstance  -Namespace "root\cimv2\security\MicrosoftTPM" -query "select * from win32_tpm where IsEnabled_InitialValue = 'True' and ((ManufacturerVersion like '7.62%') or (ManufacturerVersion like '7.63%') or (ManufacturerVersion like '7.83%') or (ManufacturerVersion like '6.43%') )"
    if ($SP87753){Return SP87753}
    elseif ($SP94937){Return SP94937}
    else{Return "NA"}
}
function osdcloud-DownloadHPTPM {
    [CmdletBinding()]
    param ($WorkingFolder)
    $ImportModule = Import-Module -Name HPCMSL -Global -Force -ErrorAction SilentlyContinue
    $Module = Get-Module -Name HPCMSL -ErrorAction SilentlyContinue
    if ($Module){
        $TPMUpdate = osdcloud-DetermineHPTPM
        if ($TPMUpdate -ne "NA")
            {
            if ((!($WorkingFolder))-or ($null -eq $WorkingFolder)){$WorkingFolder = "$env:TEMP\TPM"}
            if (!(Test-Path -Path $WorkingFolder)){New-Item -Path $WorkingFolder -ItemType Directory -Force |Out-Null}
            $UpdatePath = "$WorkingFolder\$TPMUpdate.exe"
            $extractPath = "$WorkingFolder\$TPMUpdate"
            Write-Host "Starting downlaod & Install of TPM Update $TPMUpdate"
            Get-Softpaq -Number $TPMUpdate -SaveAs $UpdatePath -Overwrite yes
            if (!(Test-Path -Path $UpdatePath)){Throw "Failed to Download TPM Update"}
            Start-Process -FilePath $UpdatePath -ArgumentList "/s /e /f $extractPath" -Wait
            if (!(Test-Path -Path $UpdatePath)){Throw "Failed to Extract TPM Update"}
            else {
                Return $UpdatePath
                }
            }
        }
    else {throw "Unable to load HPCMSL"}
    
}
function osdcloud-StartHPTPMUpdate {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        $path,
        [Parameter(Mandatory=$false)]
        $filename,
        [Parameter(Mandatory=$false)]
        $spec,
        [Parameter(Mandatory=$false)]
        $logsuffix
        )
    
    $Process = "$path\TPMConfig64.exe"
    #Create Argument List
    if ($filename -and $spec){$TPMArg = "-s -f$filename -a$spec -l$($env:temp)\TPMConfig_$($logsuffix).log"}
    elseif ($filename -and !($spec)) { $TPMArg = "-s -f$filename -l$($env:temp)\TPMConfig_$($logsuffix).log"}
    elseif (!($filename) -and $spec) { $TPMArg = "-s -a$spec -l$($env:temp)\TPMConfig_$($logsuffix).log"}
    elseif (!($filename) -and !($spec)) { $TPMArg = "-s -l$($env:temp)\TPMConfig_$($logsuffix).log"}
    
    Write-Output "Running Command: Start-Process -FilePath $Process -ArgumentList $TPMArg -PassThru -Wait"
    
    $TPMUpdate = Start-Process -FilePath $Process -ArgumentList $TPMArg -PassThru -Wait
    write-output "TPMUpdate Exit Code: $($TPMUpdate.exitcode)"
    }
function osdcloud-UpdateHPTPM {
    [CmdletBinding()]
    param ($WorkingFolder)
    $UpdatePath = osdcloud-DownloadHPTPM -WorkingFolder $WorkingFolder
    if (!(Test-Path -Path $UpdatePath)){Throw "Failed to Locate Update Path"}
    osdcloud-StartHPTPMUpdate -path $extractPath

}

function osdcloud-SetExecutionPolicy {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        if ((Get-ExecutionPolicy) -ne 'Bypass') {
            Write-Host -ForegroundColor DarkGray 'Set-ExecutionPolicy Bypass'
            Set-ExecutionPolicy Bypass -Force
        }
    }
    else {
        if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
            Write-Host -ForegroundColor DarkGray 'Set-ExecutionPolicy RemoteSigned [CurrentUser]'
            Set-ExecutionPolicy RemoteSigned -Force -Scope CurrentUser
        }
    }
}
function osdcloud-InstallPackageManagement {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
        if (-not $InstalledModule) {
            Write-Host -ForegroundColor DarkGray 'Install PackageManagement'
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
            Write-Host -ForegroundColor DarkGray 'Install-Package PackageManagement,PowerShellGet [AllUsers]'
            Install-Package -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Confirm:$false -Source PSGallery | Out-Null
    
            Write-Host -ForegroundColor DarkGray 'Import-Module PackageManagement,PowerShellGet [Global]'
            Import-Module PackageManagement,PowerShellGet -Force -Scope Global
        }
    }
}
function osdcloud-InstallModuleOSD {
    [CmdletBinding()]
    param ()
    $InstallModule = $false
    $PSModuleName = 'OSD'
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
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers -Force
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers -Force
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleAutopilot {
    [CmdletBinding()]
    param ()
    $InstalledModule = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
    if (-not $InstalledModule) {
        Write-Host -ForegroundColor DarkGray 'Install-Module AzureAD,Microsoft.Graph.Intune,WindowsAutopilotIntune [CurrentUser]'
        Install-Module WindowsAutopilotIntune -Force -Scope CurrentUser
    }
}
function osdcloud-InstallModuleAzAccounts {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Az.Accounts'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleAzKeyVault {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Az.KeyVault'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleAzResources {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Az.Resources'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleAzStorage {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Az.Storage'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleAzureAD {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'AzureAD'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleMSGraphAuthentication {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Microsoft.Graph.Authentication'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallModuleMSGraphDeviceManagement {
    [CmdletBinding()]
    param ()
    $PSModuleName = 'Microsoft.Graph.DeviceManagement'
    $InstalledModule = Get-InstalledModule $PSModuleName -ErrorAction Ignore | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore

    if ($InstalledModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            if ($WindowsPhase -eq 'WinPE') {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
                Update-Module -Name $PSModuleName -Scope AllUsers -Force
                Import-Module $PSModuleName -Force
            }
            else {
                Write-Host -ForegroundColor DarkGray "Update-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
                Update-Module -Name $PSModuleName -Scope CurrentUser -Force
                Import-Module $PSModuleName -Force
            } 
        }
    }
    else {
        if ($WindowsPhase -eq 'WinPE') {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [AllUsers]"
            Install-Module $PSModuleName -Scope AllUsers
        }
        else {
            Write-Host -ForegroundColor DarkGray "Install-Module $PSModuleName $($GalleryPSModule.Version) [CurrentUser]"
            Install-Module $PSModuleName -Scope CurrentUser
        }
    }
    Import-Module $PSModuleName -Force
}
function osdcloud-InstallScriptAutopilot {
    [CmdletBinding()]
    param ()
    $InstalledScript = Get-InstalledScript -Name Get-WindowsAutoPilotInfo -ErrorAction SilentlyContinue
    if (-not $InstalledScript) {
        Write-Host -ForegroundColor DarkGray 'Install-Script Get-WindowsAutoPilotInfo [AllUsers]'
        Install-Script -Name Get-WindowsAutoPilotInfo -Force -Scope AllUsers
    }
}
function osdcloud-RestartComputer {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor Green 'Complete!'
    Write-Warning 'Device will restart in 30 seconds.  Press Ctrl + C to cancel'
    Start-Sleep -Seconds 30
    Restart-Computer
}
function osdcloud-StopComputer {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor Green 'Complete!'
    Write-Warning 'Device will shutdown in 30 seconds.  Press Ctrl + C to cancel'
    Start-Sleep -Seconds 30
    Stop-Computer
}
function osdcloud-GetAutopilotEvents {
    [CmdletBinding()]
    param ()
    Get-WinEvent -MaxEvents 25 -LogName 'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/AutoPilot' | Sort-Object TimeCreated | Select-Object TimeCreated, Id, Message | Format-Table
}
function osdcloud-ShowAutopilotProfile {
    [CmdletBinding()]
    param ()
    $Global:RegAutopilot = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot'

    #Oter Keys
    #Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache'
    #Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot\EstablishedCorrelations'
    
    if ($Global:RegAutoPilot.CloudAssignedForcedEnrollment -eq 1) {
        Write-Host -ForegroundColor Cyan "This device has an Autopilot Profile"
        Write-Host -ForegroundColor DarkGray "  TenantDomain: $($Global:RegAutoPilot.CloudAssignedTenantDomain)"
        Write-Host -ForegroundColor DarkGray "  TenantId: $($Global:RegAutoPilot.TenantId)"
        Write-Host -ForegroundColor DarkGray "  CloudAssignedLanguage: $($Global:RegAutoPilot.CloudAssignedLanguage)"
        Write-Host -ForegroundColor DarkGray "  CloudAssignedMdmId: $($Global:RegAutoPilot.CloudAssignedMdmId)"
        Write-Host -ForegroundColor DarkGray "  CloudAssignedOobeConfig: $($Global:RegAutoPilot.CloudAssignedOobeConfig)"
        Write-Host -ForegroundColor DarkGray "  CloudAssignedRegion: $($Global:RegAutoPilot.CloudAssignedRegion)"
        Write-Host -ForegroundColor DarkGray "  CloudAssignedTelemetryLevel: $($Global:RegAutoPilot.CloudAssignedTelemetryLevel)"
        Write-Host -ForegroundColor DarkGray "  AutopilotServiceCorrelationId: $($Global:RegAutoPilot.AutopilotServiceCorrelationId)"
        Write-Host -ForegroundColor DarkGray "  IsAutoPilotDisabled: $($Global:RegAutoPilot.IsAutoPilotDisabled)"
        Write-Host -ForegroundColor DarkGray "  IsDevicePersonalized: $($Global:RegAutoPilot.IsDevicePersonalized)"
        Write-Host -ForegroundColor DarkGray "  IsForcedEnrollmentEnabled: $($Global:RegAutoPilot.IsForcedEnrollmentEnabled)"
        Write-Host -ForegroundColor DarkGray "  SetTelemetryLevel_Succeeded_With_Level: $($Global:RegAutoPilot.SetTelemetryLevel_Succeeded_With_Level)"
    }
    else {
        Write-Warning 'Could not find an Autopilot Profile on this device.  If this device is registered, restart the device while connected to the internet'
    }
}
New-Alias -Name 'osdcloud-ShowAutopilotInfo' -Value 'osdcloud-ShowAutopilotProfile' -Description 'OSDCloud' -Force
function osdcloud-TestAutopilotProfile {
    [CmdletBinding()]
    param ()
    $Global:RegAutopilot = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot'

    #Oter Keys
    #Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache'
    #Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot\EstablishedCorrelations'
    
    if ($Global:RegAutoPilot.CloudAssignedForcedEnrollment -eq 1) {
        $true
    }
    else {
        $false
    }
}
#endregion
#=================================================
#region WinPE Startup
if ($WindowsPhase -eq 'WinPE') {
    function osdcloud-StartWinPE {
        [CmdletBinding()]
        param (
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $Azure,

            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $KeyVault,

            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $OSDCloud
        )
        if ($env:SystemDrive -eq 'X:') {
            osdcloud-SetExecutionPolicy
            osdcloud-SetEnvironmentVariables
            osdcloud-SetPowerShellProfile
            #osdcloud-InstallNuget
            osdcloud-InstallPackageManagement
            osdcloud-InstallPowerShellGet
            osdcloud-TrustPSGallery
            if ($OSDCloud) {
                osdcloud-InstallCurl
                osdcloud-InstallModuleOSD
                if (-not (Get-Command 'curl.exe' -ErrorAction SilentlyContinue)) {
                    Write-Warning 'curl.exe is missing from WinPE. This is required for OSDCloud to function'
                    Start-Sleep -Seconds 5
                    Break
                }
            if ($Manufacturer -eq "HP"){
                Write-Host "Detected Device to be HP, Loading HPCMSL"
                osdcloud-InstallModuleHPCMSL
                $TPMUpdateAvailable = osdcloud-DetermineHPTPM
                if ($TPMUpdateAvailable -ne "NA"){Write-Host "There is a TPM Update Available for this Machine: $TPMUpdateAvailable"}
                }
            if (($Manufacturer -match "Microsoft") -and ($Model -match "Virtual")){
                Write-Host "Detected Device to be HyperV VM, Ejecting CD"
                osdcloud-EjectCD
                }
            }
            if ($Azure) {
                $KeyVault = $false
                osdcloud-InstallModuleAzureAD
                osdcloud-InstallModuleAzAccounts
                osdcloud-InstallModuleAzKeyVault
                osdcloud-InstallModuleAzResources
                osdcloud-InstallModuleAzStorage
                osdcloud-InstallModuleMSGraphDeviceManagement
            }
            if ($KeyVault) {
                osdcloud-InstallModuleAzAccounts
                osdcloud-InstallModuleAzKeyVault
            }
        }
        else {
            Write-Warning 'Function is not supported in this Windows Phase'
        }
    }
    New-Alias -Name 'Start-WinPE' -Value 'osdcloud-StartWinPE' -Description 'OSDCloud' -Force
}
#endregion
#=================================================
#region OOBE Startup
if ($WindowsPhase -eq 'OOBE') {
    function osdcloud-StartOOBE {
        [CmdletBinding()]
        param (
            [System.Management.Automation.SwitchParameter]
            #Install Autopilot Support
            $Autopilot,

            [System.Management.Automation.SwitchParameter]
            #Show Windows Settings Display
            $Display,

            [System.Management.Automation.SwitchParameter]
            #Show Windows Settings Display
            $Language,

            [System.Management.Automation.SwitchParameter]
            #Show Windows Settings Display
            $DateTime,

            [System.Management.Automation.SwitchParameter]
            #Install Azure support
            $Azure,

            [System.Management.Automation.SwitchParameter]
            #Install Azure KeyVault support
            $KeyVault
        )
        if ($Display) {
            osdcloud-SetWindowsDisplay
        }
        if ($Language) {
            osdcloud-SetWindowsLanguage
        }
        if ($DateTime) {
            osdcloud-SetWindowsDateTime
        }
        osdcloud-SetExecutionPolicy
        osdcloud-SetPowerShellProfile
        osdcloud-InstallPackageManagement
        osdcloud-TrustPSGallery
        osdcloud-InstallModuleOSD
        if ($Manufacturer -eq "HP"){
            osdcloud-InstallModuleHPCMSL
            }
        #Add Azure KeuVault Support
        if ($Azure) {
            osdcloud-InstallModuleAzAccounts
            osdcloud-InstallModuleAzKeyVault
        }

        #Add Azure KeuVault Support
        if ($KeyVault) {
            osdcloud-InstallModuleAzAccounts
            osdcloud-InstallModuleAzKeyVault
        }

        #Get Autopilot information from the device
        $TestAutopilotProfile = osdcloud-TestAutopilotProfile

        #If the device has an Autopilot Profile, show the information
        if ($TestAutopilotProfile -eq $true) {
            osdcloud-ShowAutopilotProfile
            $Autopilot = $false
        }
        
        #Install the required Autopilot Modules
        if ($Autopilot) {
            if ($TestAutopilotProfile -eq $false) {
                osdcloud-InstallModuleAutopilot
                osdcloud-InstallModuleAzureAD
                osdcloud-InstallScriptAutopilot
            }
        }
    }
    New-Alias -Name 'Start-OOBE' -Value 'osdcloud-StartOOBE' -Description 'OSDCloud' -Force
}
#endregion
#=================================================
#region AzOSDCloud Functions
function Connect-MgOSDCloud {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Connect-MgOSDCloud"

    osdcloud-InstallModuleAzureAD
    osdcloud-InstallModuleAzAccounts
    osdcloud-InstallModuleAzKeyVault
    osdcloud-InstallModuleAzResources
    osdcloud-InstallModuleAzStorage
    osdcloud-InstallModuleMSGraphAuthentication
    osdcloud-InstallModuleMSGraphDeviceManagement

    Connect-AzAccount -UseDeviceAuthentication -AuthScope Storage -ErrorAction Stop
    $Global:AzSubscription = Get-AzSubscription

    if (($Global:AzSubscription).Count -ge 2) {
        $i = $null
        $Results = foreach ($Item in $Global:AzSubscription) {
            $i++
    
            $ObjectProperties = @{
                Number  = $i
                Name    = $Item.Name
                Id      = $Item.Id
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }
    
        $Results | Select-Object -Property Number, Name, Id | Format-Table | Out-Host
    
        do {
            $SelectReadHost = Read-Host -Prompt "Select an Azure Subscription by Number"
        }
        until (((($SelectReadHost -ge 0) -and ($SelectReadHost -in $Results.Number))))
    
        $Results = $Results | Where-Object {$_.Number -eq $SelectReadHost}
    
        $Global:AzContext = Set-AzContext -Subscription $Results.Id
    }
    else {
        $Global:AzContext = Get-AzContext
    }

    if ($Global:AzContext) {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Green 'Welcome to Azure OSDCloud!'
        $Global:AzAccount = $Global:AzContext.Account
        $Global:AzEnvironment = $Global:AzContext.Environment
        $Global:AzTenantId = $Global:AzContext.Tenant
        $Global:AzSubscription = $Global:AzContext.Subscription

        Write-Host -ForegroundColor Cyan        '$Global:AzAccount:        ' $Global:AzAccount
        Write-Host -ForegroundColor Cyan        '$Global:AzEnvironment:    ' $Global:AzEnvironment
        Write-Host -ForegroundColor Cyan        '$Global:AzTenantId:       ' $Global:AzTenantId
        Write-Host -ForegroundColor Cyan        '$Global:AzSubscription:   ' $Global:AzSubscription
        if ($null -eq $Global:AzContext.Subscription) {
            Write-Warning 'You do not have access to an Azure Subscriptions'
            Write-Warning 'This is likely due to not having rights to Azure Resources or Azure Storage'
            Write-Warning 'Contact your Azure administrator to resolve this issue'
            Break
        }

        Write-Host ''
        Write-Host -ForegroundColor DarkGray    'Azure Context:             $Global:AzContext'
        Write-Host -ForegroundColor DarkGray    'Access Tokens:             $Global:Az*AccessToken'
        Write-Host -ForegroundColor DarkGray    'Headers:                   $Global:Az*Headers'
        Write-Host ''
        #=================================================
        #	AAD Graph
        #=================================================
        $Global:AzAadGraphAccessToken = Get-AzAccessToken -ResourceTypeName AadGraph
        $Global:AzAadGraphHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzAadGraphAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzAadGraphAccessToken.ExpiresOn
        }
        #=================================================
        #	Azure KeyVault
        #=================================================
        $Global:AzKeyVaultAccessToken = Get-AzAccessToken -ResourceTypeName KeyVault
        $Global:AzKeyVaultHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzKeyVaultAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzKeyVaultAccessToken.ExpiresOn
        }
        #=================================================
        #	Azure MSGraph
        #=================================================
        $Global:AzMSGraphAccessToken = Get-AzAccessToken -ResourceTypeName MSGraph
        $Global:AzMSGraphHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzMSGraphAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzMSGraphHeaders.ExpiresOn
        }
        #=================================================
        #	Azure Storage
        #=================================================
        $Global:AzStorageAccessToken = Get-AzAccessToken -ResourceTypeName Storage
        $Global:AzStorageHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzStorageAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzStorageHeaders.ExpiresOn
        }
        #=================================================
        #	AzureAD
        #=================================================
        #$Global:MgGraph = Connect-MgGraph -AccessToken $Global:AzMSGraphAccessToken.Token -Scopes DeviceManagementConfiguration.Read.All,DeviceManagementServiceConfig.Read.All,DeviceManagementServiceConfiguration.Read.All
        #$Global:AzureAD = Connect-AzureAD -AadAccessToken $Global:AzAadGraphAccessToken.Token -AccountId $Global:AzContext.Account.Id
        $Global:MgGraph = Connect-MgGraph -AccessToken $Global:AzMSGraphAccessToken.Token
    }
    else {
        Write-Warning 'Unable to get AzContext'
    }
}
function Connect-AzOSDCloud {
    [CmdletBinding()]
    param (
        [System.Management.Automation.SwitchParameter]
        $UseDeviceAuthentication
    )
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Connect-AzOSDCloud"

    if ($env:SystemDrive -eq 'X:') {
        $UseDeviceAuthentication = $true
    }

    osdcloud-InstallModuleAzureAD
    osdcloud-InstallModuleAzAccounts
        #Connect-AzAccount
        #Get-AzSubscription
        #Set-AzContext
        #Get-AzContext
        #Get-AzAccessToken
    osdcloud-InstallModuleAzKeyVault
    osdcloud-InstallModuleAzResources
    osdcloud-InstallModuleAzStorage
    osdcloud-InstallModuleMSGraphAuthentication
    osdcloud-InstallModuleMSGraphDeviceManagement

    if ($UseDeviceAuthentication) {
        Connect-AzAccount -UseDeviceAuthentication -AuthScope Storage -ErrorAction Stop
    }
    else {
        Connect-AzAccount -AuthScope Storage -ErrorAction Stop
    }

    $Global:AzSubscription = Get-AzSubscription

    if (($Global:AzSubscription).Count -ge 2) {
        $i = $null
        $Results = foreach ($Item in $Global:AzSubscription) {
            $i++
    
            $ObjectProperties = @{
                Number  = $i
                Name    = $Item.Name
                Id      = $Item.Id
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }
    
        $Results | Select-Object -Property Number, Name, Id | Format-Table | Out-Host
    
        do {
            $SelectReadHost = Read-Host -Prompt "Select an Azure Subscription by Number"
        }
        until (((($SelectReadHost -ge 0) -and ($SelectReadHost -in $Results.Number))))
    
        $Results = $Results | Where-Object {$_.Number -eq $SelectReadHost}
    
        $Global:AzContext = Set-AzContext -Subscription $Results.Id
    }
    else {
        $Global:AzContext = Get-AzContext
    }

    if ($Global:AzContext) {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Green 'Welcome to Azure OSDCloud!'
        $Global:AzAccount = $Global:AzContext.Account
        $Global:AzEnvironment = $Global:AzContext.Environment
        $Global:AzTenantId = $Global:AzContext.Tenant
        $Global:AzSubscription = $Global:AzContext.Subscription

        Write-Host -ForegroundColor Cyan        '$Global:AzAccount:        ' $Global:AzAccount
        Write-Host -ForegroundColor Cyan        '$Global:AzEnvironment:    ' $Global:AzEnvironment
        Write-Host -ForegroundColor Cyan        '$Global:AzTenantId:       ' $Global:AzTenantId
        Write-Host -ForegroundColor Cyan        '$Global:AzSubscription:   ' $Global:AzSubscription
        if ($null -eq $Global:AzContext.Subscription) {
            Write-Warning 'You do not have access to an Azure Subscriptions'
            Write-Warning 'This is likely due to not having rights to Azure Resources or Azure Storage'
            Write-Warning 'Contact your Azure administrator to resolve this issue'
            Break
        }

        Write-Host ''
        Write-Host -ForegroundColor DarkGray    'Azure Context:             $Global:AzContext'
        Write-Host -ForegroundColor DarkGray    'Access Tokens:             $Global:Az*AccessToken'
        Write-Host -ForegroundColor DarkGray    'Headers:                   $Global:Az*Headers'
        Write-Host ''
        #=================================================
        #	AAD Graph
        #=================================================
        $Global:AzAadGraphAccessToken = Get-AzAccessToken -ResourceTypeName AadGraph
        $Global:AzAadGraphHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzAadGraphAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzAadGraphAccessToken.ExpiresOn
        }
        #=================================================
        #	Azure KeyVault
        #=================================================
        $Global:AzKeyVaultAccessToken = Get-AzAccessToken -ResourceTypeName KeyVault
        $Global:AzKeyVaultHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzKeyVaultAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzKeyVaultAccessToken.ExpiresOn
        }
        #=================================================
        #	Azure MSGraph
        #=================================================
        $Global:AzMSGraphAccessToken = Get-AzAccessToken -ResourceTypeName MSGraph
        $Global:AzMSGraphHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzMSGraphAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzMSGraphHeaders.ExpiresOn
        }
        #=================================================
        #	Azure Storage
        #=================================================
        $Global:AzStorageAccessToken = Get-AzAccessToken -ResourceTypeName Storage
        $Global:AzStorageHeaders = @{
            'Authorization' = 'Bearer ' + $Global:AzStorageAccessToken.Token
            'Content-Type'  = 'application/json'
            'ExpiresOn'     = $Global:AzStorageHeaders.ExpiresOn
        }
        #=================================================
        #	AzureAD
        #=================================================
        #$Global:MgGraph = Connect-MgGraph -AccessToken $Global:AzMSGraphAccessToken.Token -Scopes DeviceManagementConfiguration.Read.All,DeviceManagementServiceConfig.Read.All,DeviceManagementServiceConfiguration.Read.All
        $Global:AzureAD = Connect-AzureAD -AadAccessToken $Global:AzAadGraphAccessToken.Token -AccountId $Global:AzContext.Account.Id
    }
    else {
        Write-Warning 'Unable to get AzContext'
    }
}
New-Alias -Name 'Connect-AzWinPE' -Value 'Connect-AzOSDCloud' -Description 'OSDCloud' -Force
New-Alias -Name 'Connect-AzureWinPE' -Value 'Connect-AzOSDCloud' -Description 'OSDCloud' -Force
function Get-AzOSDCloudBlobImage {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Get-AzOSDCloudBlobImage"

    if ($Global:AzureAD -or $Global:MgGraph) {
        Write-Host -ForegroundColor DarkGray    'Storage Accounts:          $Global:AzStorageAccounts'
        $Global:AzStorageAccounts = Get-AzStorageAccount
    
        Write-Host -ForegroundColor DarkGray    'OSDCloud Storage Accounts: $Global:AzOSDCloudStorageAccounts'
        #$Global:AzOSDCloudStorageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts'
        #$Global:AzOSDCloudStorageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' | Where-Object {$_.Tags.ContainsKey('OSDCloud')}
        $Global:AzOSDCloudStorageAccounts = Get-AzStorageAccount | Where-Object {$_.Tags.ContainsKey('OSDCloud')}
    
        Write-Host -ForegroundColor DarkGray    'Storage Contexts:          $Global:AzStorageContext'
        Write-Host -ForegroundColor DarkGray    'Blob Windows Images:       $Global:AzOSDCloudBlobImage'
        Write-Host ''
        $Global:AzStorageContext = @{}
        $Global:AzOSDCloudBlobImage = @()
    
        if ($Global:AzOSDCloudStorageAccounts) {
            Write-Host -ForegroundColor Cyan "Scanning for Windows Images"
            foreach ($Item in $Global:AzOSDCloudStorageAccounts) {
                $Global:AzCurrentStorageContext = New-AzStorageContext -StorageAccountName $Item.StorageAccountName
                $Global:AzStorageContext."$($Item.StorageAccountName)" = $Global:AzCurrentStorageContext
                #Get-AzStorageBlobByTag -TagFilterSqlExpression ""osdcloudimage""=""win10ltsc"" -Context $StorageContext
                #Get-AzStorageBlobByTag -Context $Global:AzCurrentStorageContext
        
                $StorageContainers = Get-AzStorageContainer -Context $Global:AzCurrentStorageContext
            
                if ($StorageContainers) {
                    foreach ($Container in $StorageContainers) {
                        Write-Host -ForegroundColor DarkGray "Storage Account: $($Item.StorageAccountName) Container: $($Container.Name)"
                        $Global:AzOSDCloudBlobImage += Get-AzStorageBlob -Context $Global:AzCurrentStorageContext -Container $Container.Name -Blob *.wim -ErrorAction Ignore
                    }
                }
            }
        }
        else {
            Write-Warning 'Unable to find any Azure Storage Accounts'
            Write-Warning 'Make sure the OSDCloud Azure Storage Account has an OSDCloud Tag'
            Write-Warning 'Make sure this user has the Azure Reader role on the OSDCloud Azure Storage Account'
        }
    }
    else {
        Write-Warning 'Unable to connect to AzureAD'
        Write-Warning 'You may need to execute Connect-AzOSDCloud then Start-AzOSDCloud'
    }
}

function Get-AzOSDCloudScript {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Get-AzOSDCloudScript"

    if ($Global:AzureAD -or $Global:MgGraph) {
        Write-Host -ForegroundColor DarkGray    'Storage Accounts:          $Global:AzStorageAccounts'
        $Global:AzStorageAccounts = Get-AzStorageAccount
    
        Write-Host -ForegroundColor DarkGray    'OSDCloud Storage Accounts: $Global:AzOSDCloudStorageAccounts'
        $Global:AzOSDCloudStorageAccounts = Get-AzStorageAccount | Where-Object {$_.Tags.ContainsKey('OSDScripts')}
    
        Write-Host -ForegroundColor DarkGray    'Storage Contexts:          $Global:AzStorageContext'
        Write-Host -ForegroundColor DarkGray    'Blob PowerShell Scripts:       $Global:AzOSDCloudBlobScript'
        Write-Host ''
        $Global:AzStorageContext = @{}
        $Global:AzOSDCloudBlobScript = @()
    
        if ($Global:AzOSDCloudStorageAccounts) {
            Write-Host -ForegroundColor Cyan "Scanning for PowerShell Script"
            foreach ($Item in $Global:AzOSDCloudStorageAccounts) {
                $Global:AzCurrentStorageContext = New-AzStorageContext -StorageAccountName $Item.StorageAccountName
                $Global:AzStorageContext."$($Item.StorageAccountName)" = $Global:AzCurrentStorageContext      
                $StorageContainers = Get-AzStorageContainer -Context $Global:AzCurrentStorageContext
                if ($StorageContainers) {
                    foreach ($Container in $StorageContainers) {
                        Write-Host -ForegroundColor DarkGray "Storage Account: $($Item.StorageAccountName) Container: $($Container.Name)"
                        $Global:AzOSDCloudBlobScript += Get-AzStorageBlob -Context $Global:AzCurrentStorageContext -Container $Container.Name -Blob *.ps1 -ErrorAction Ignore
                        #$Global:AzOSDCloudBlobScript += Get-AzStorageBlob -Context $Global:AzCurrentStorageContext -Container $Container.Name -Blob *.ppkg -ErrorAction Ignore
                        #$Global:AzOSDCloudBlobScript += Get-AzStorageBlob -Context $Global:AzCurrentStorageContext -Container $Container.Name -Blob *.xml -ErrorAction Ignore

                    }
                }
            }
           # return $Global:AzOSDCloudBlobScript
        }
        else {
            Write-Warning 'Unable to find any Azure Storage Accounts'
            Write-Warning 'Make sure the OSDCloud Azure Storage Account has an OSDScripts Tag'
            Write-Warning 'Make sure this user has the Azure Reader role on the OSDCloud Azure Storage Account'
        }
    }
    else {
        Write-Warning 'Unable to connect to AzureAD'
        Write-Warning 'You may need to execute Connect-AzOSDCloud '
    }
}
function Start-AzOSDCloud {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Start-AzOSDCloud"
    if ($Global:AzOSDCloudBlobImage) {
        $i = $null
        $Results = foreach ($Item in $Global:AzOSDCloudBlobImage) {
            $i++
            
            $BlobClient = $Global:AzOSDCloudStorageAccounts | Where-Object {$_.StorageAccountName -eq $Item.BlobClient.AccountName}

            $ObjectProperties = @{
                Number          = $i
                StorageAccount  = $Item.BlobClient.AccountName
                Tag             = ($BlobClient | Select-Object -ExpandProperty Tags).Get_Item('OSDCloud')
                Container       = $Item.BlobClient.BlobContainerName
                Blob            = $Item.Name
                Location        = $BlobClient | Select-Object -ExpandProperty Location
                ResourceGroup   = $BlobClient | Select-Object -ExpandProperty ResourceGroupName
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }

        $Results | Select-Object -Property Number, StorageAccount, Tag, Container, Blob, Location, ResourceGroup | Format-Table | Out-Host

        do {
            $SelectReadHost = Read-Host -Prompt "Select a Windows Image to apply by Number"
        }
        until (((($SelectReadHost -ge 0) -and ($SelectReadHost -in $Results.Number))))

        $Results = $Results | Where-Object {$_.Number -eq $SelectReadHost}
        $Results

        $Global:AzOSDCloudImage = $Global:AzOSDCloudBlobImage | Where-Object {$_.Name -eq $Results.Blob}
        $Global:AzOSDCloudImage = $Global:AzOSDCloudImage | Where-Object {$_.BlobClient.BlobContainerName -eq $Results.Container}
        $Global:AzOSDCloudImage = $Global:AzOSDCloudImage | Where-Object {$_.BlobClient.AccountName -eq $Results.StorageAccount}
        $Global:AzOSDCloudImage | Select-Object * | Export-Clixml "$env:SystemDrive\AzOSDCloudImage.xml"
        $Global:AzOSDCloudImage | Select-Object * | ConvertTo-Json | Out-File "$env:SystemDrive\AzOSDCloudImage.json"
        #=================================================
        #   Invoke-OSDCloud.ps1
        #=================================================
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Green "Invoke-OSDCloud ... Starting in 5 seconds..."
        Start-Sleep -Seconds 5
        Invoke-OSDCloud
    }
    else {
        Write-Warning 'Unable to find a WIM on any of the OSDCloud Azure Storage Containers'
        Write-Warning 'Make sure you have a WIM Windows Image in the OSDCloud Azure Storage Container'
        Write-Warning 'Make sure this user has the Azure Storage Blob Data Reader role to the OSDCloud Container'
        Write-Warning 'You may need to execute Get-AzOSDCloudBlobImage then Start-AzOSDCloud'
    }
}
New-Alias -Name 'Start-AzOSDCloudBeta' -Value 'Start-AzOSDCloud' -Description 'OSDCloud' -Force

function Start-AzOSDPADbeta {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Start-AzOSDPAD"
    if ($Global:AzOSDCloudBlobScript) {
        $i = $null
        $Results = foreach ($Item in $Global:AzOSDCloudBlobScript) {
            $i++
            
            $BlobClient = $Global:AzOSDCloudStorageAccounts | Where-Object {$_.StorageAccountName -eq $Item.BlobClient.AccountName}

            $ObjectProperties = @{
                Number          = $i
                StorageAccount  = $Item.BlobClient.AccountName
                Tag             = ($BlobClient | Select-Object -ExpandProperty Tags).Get_Item('OSDScripts')
                Container       = $Item.BlobClient.BlobContainerName
                Blob            = $Item.Name
                Location        = $BlobClient | Select-Object -ExpandProperty Location
                ResourceGroup   = $BlobClient | Select-Object -ExpandProperty ResourceGroupName
            }
            New-Object -TypeName PSObject -Property $ObjectProperties
        }

        $Results | Select-Object -Property Number, StorageAccount, Tag, Container, Blob, Location, ResourceGroup | Format-Table | Out-Host

        do {
            $SelectReadHost = Read-Host -Prompt "Select a Windows Image to apply by Number"
        }
        until (((($SelectReadHost -ge 0) -and ($SelectReadHost -in $Results.Number))))

        $Results = $Results | Where-Object {$_.Number -eq $SelectReadHost}
        $Results

        $Global:AzOSDCloudGlobalScripts = $Global:AzOSDCloudBlobScript | Where-Object {$_.Name -eq $Results.Blob}
        $Global:AzOSDCloudGlobalScripts = $Global:AzOSDCloudGlobalScripts | Where-Object {$_.BlobClient.BlobContainerName -eq $Results.Container}
        $Global:AzOSDCloudGlobalScripts = $Global:AzOSDCloudGlobalScripts | Where-Object {$_.BlobClient.AccountName -eq $Results.StorageAccount}
            # Path for Test only
        $Global:AzOSDCloudGlobalScripts | Select-Object * | Export-Clixml "d:\OSD\AzOSDCloudScript.xml"
        $Global:AzOSDCloudGlobalScripts | Select-Object * | ConvertTo-Json | Out-File "d:\OSD\AzOSDCloudScripts.json"
        #=================================================
        #   Invoke-OSDCloud.ps1
        #=================================================
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Green "Invoke-OSDCloud ... Starting in 5 seconds..."
        Start-Sleep -Seconds 5
        #Invoke-OSDCloud
    }
    else {
        Write-Warning 'Unable to find a WIM on any of the OSDCloud Azure Storage Containers'
        Write-Warning 'Make sure you have a WIM Windows Image in the OSDCloud Azure Storage Container'
        Write-Warning 'Make sure this user has the Azure Storage Blob Data Reader role to the OSDCloud Container'
        Write-Warning 'You may need to execute Get-AzOSDCloudBlobImage then Start-AzOSDCloud'
    }
}


#endregion
#=================================================
