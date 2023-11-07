$ScriptName = 'functions.garytown.com'
$ScriptVersion = '23.11.01.4'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Start-DISMFromOSDCloudUSB"
Function Test-DISMFromOSDCloudUSB {
    #region Initialize
    #require OSD Module Installed

    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $ComputerProduct = (Get-MyComputerProduct)
    $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
    $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
    if (Test-Path $DriverPath){Return $true}
    else { Return $false}

}
Write-Host -ForegroundColor Green "[+] Function Get-UBR"
function Get-UBR {
    if ($env:SystemDrive -eq "X:"){
        $Info = DISM.exe /image:c:\ /Get-CurrentEdition
        $UBR = ($Info | Where-Object {$_ -match "Image Version"}).replace("Image Version: ","")
    }
    else {
        $Info = DISM.exe /online /Get-CurrentEdition
        $UBR = ($Info | Where-Object {$_ -match "Image Version"}).replace("Image Version: ","")
    }
    return $UBR
}

Function Start-DISMFromOSDCloudUSB {
    #region Initialize
    if ($env:SystemDrive -eq 'X:') {
        $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
        $ComputerProduct = (Get-MyComputerProduct)
        $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
        $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
        Write-Host "Checking location for Drivers: $DriverPath" -ForegroundColor Green
        if (Test-Path $DriverPath){
            Write-Host "Found Drivers: $DriverPath" -ForegroundColor Green
            Write-Host "Starting DISM of drivers while Offline" -ForegroundColor Green
            $DismPath = "$env:windir\System32\Dism.exe"
            $DismProcess = Start-Process -FilePath $DismPath -ArgumentList "/image:c:\ /Add-Driver /driver:$($DriverPath) /recurse" -Wait -PassThru
            Write-Host "Finished Process with Exit Code: $($DismProcess.ExitCode)"
        }
    }
    else {
        Write-Output "Skipping Run-DISMFromOSDCloudUSB Function, not running in WinPE"
    }
}
Write-Host -ForegroundColor Green "[+] Function Install-Update"
Function Install-Update {
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory=$true)]
	$UpdatePath
    )

    $scratchdir = 'C:\OSDCloud\Temp'
    if (!(Test-Path -Path $scratchdir)){
        new-item -Path $scratchdir | Out-Null
    }

    if ($env:SystemDrive -eq "X:"){
        $Process = "X:\Windows\system32\Dism.exe"
        $DISMArg = "/Image:C:\ /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
    }
    else {
        $Process = "C:\Windows\system32\Dism.exe"
        $DISMArg = "/Online /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
    }


    Write-Output "Starting Process of $Process -ArgumentList $DismArg -Wait"
    $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru
    
    return $DISM.ExitCode
}
Write-Host -ForegroundColor Green "[+] Function Disable-CloudContent"
Function Disable-CloudContent {
    New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name "CloudContent" -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType Dword -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableSoftLanding' -Value 1 -PropertyType Dword -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableCloudOptimizedContent' -Value 1 -PropertyType Dword -Force | out-null
}

Write-Host -ForegroundColor Green "[+] Set-Win11ReqBypassRegValues"
Function Set-Win11ReqBypassRegValues {
    if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
    }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
        else {$WindowsPhase = 'Windows'}
    }
    
    if ($WindowsPhase -eq 'WinPE'){
        #Insipiration & Some code from: https://github.com/JosephM101/Force-Windows-11-Install/blob/main/Win11-TPM-RegBypass.ps1
    
        # Mount and edit the setup environment's registry
        $REG_System = "C:\Windows\System32\config\system"
        $VirtualRegistryPath_SYSTEM = "HKLM\WinPE_SYSTEM" #Load Command
        $VirtualRegistryPath_Setup = "HKLM:\WinPE_SYSTEM\Setup" #PowerShell Path

        # $VirtualRegistryPath_LabConfig = $VirtualRegistryPath_Setup + "\LabConfig"
        reg unload $VirtualRegistryPath_SYSTEM | Out-Null # Just in case...
        Start-Sleep 1
        reg load $VirtualRegistryPath_SYSTEM $REG_System | Out-Null


       
        New-Item -Path $VirtualRegistryPath_Setup -Name "LabConfig" -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force | out-null

        New-Item -Path $VirtualRegistryPath_Setup -Name "MoSetup" -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force | out-null


        Start-Sleep 1
        reg unload $VirtualRegistryPath_SYSTEM
    }
    else {
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\LabConfig)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "LabConfig" | out-null
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force | out-null
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\MoSetup)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "MoSetup" | out-null
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force | out-null
    }
}

Write-Host -ForegroundColor Green "[+] Start-WindowsUpdate"
function Start-WindowsUpdate{
    <# Control Windows Update via PowerShell
    Gary Blok - GARYTOWN.COM
    NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
    In a normal script, you wouldn't do this... so modify for your deployment method.

    This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

    Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

    HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

    #>

    $Results = @(
    @{ ResultCode = '0'; Meaning = "Not Started"}
    @{ ResultCode = '1'; Meaning = "In Progress"}
    @{ ResultCode = '2'; Meaning = "Succeeded"}
    @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
    @{ ResultCode = '4'; Meaning = "Failed"}
    @{ ResultCode = '5'; Meaning = "Aborted"}
    @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )


    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Software'")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }

    if ($WUUpdates.Count -ge 1){
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        if ($UpdateCount -ge 1){
            Write-Output "Downloading $UpdateCount Updates"
            foreach ($update in $WUInstaller.Updates){Write-Output "$($update.Title)"}
            $Download = $WUDownloader.Download()
        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        if ($InstallUpdateCount -ge 1){
            Write-Output "Installing $InstallUpdateCount Updates"
            $Install = $WUInstaller.Install()
            $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
            Write-Output $ResultMeaning
        } 
    }
    else {Write-Output "No Updates Found"} 
}

Write-Host -ForegroundColor Green "[+] Start-WindowsUpdateDriver"
function Start-WindowsUpdateDriver{
    <# Control Windows Update via PowerShell
    Gary Blok - GARYTOWN.COM
    NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
    In a normal script, you wouldn't do this... so modify for your deployment method.

    This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

    Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

    HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

    #>

    $Results = @(
    @{ ResultCode = '0'; Meaning = "Not Started"}
    @{ ResultCode = '1'; Meaning = "In Progress"}
    @{ ResultCode = '2'; Meaning = "Succeeded"}
    @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
    @{ ResultCode = '4'; Meaning = "Failed"}
    @{ ResultCode = '5'; Meaning = "Aborted"}
    @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )


    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Driver'")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }

    if ($WUUpdates.Count -ge 1){
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        if ($UpdateCount -ge 1){
            Write-Output "Downloading $UpdateCount Updates"
            foreach ($update in $WUInstaller.Updates){Write-Output "$($update.Title)"}
            $Download = $WUDownloader.Download()
        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        if ($InstallUpdateCount -ge 1){
            Write-Output "Installing $InstallUpdateCount Updates"
            $Install = $WUInstaller.Install()
            $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
            Write-Output $ResultMeaning
        } 
    }
    else {Write-Output "No Updates Found"} 
}

Write-Host -ForegroundColor Green "[+] Enable-AutoZimeZoneUpdate"
Function Enable-AutoZimeZoneUpdate {

    if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
    }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
        else {$WindowsPhase = 'Windows'}
    }
    
    if ($WindowsPhase -eq 'WinPE'){
    
        # Mount and edit the setup environment's registry
        $REG_System = "C:\Windows\System32\config\system"
        $REG_Software = "C:\Windows\system32\config\SOFTWARE"
        $VirtualRegistryPath_SYSTEM = "HKLM\WinPE_SYSTEM"#Load Command
        $VirtualRegistryPath_SOFTWARE = "HKLM\WinPE_SOFTWARE"#Load Command
        $VirtualRegistryPath_tzautoupdate = "HKLM:\WinPE_SYSTEM\CurrentControlSet\Services\tzautoupdate" #PowerShell Path
        $VirtualRegistryPath_location = "HKLM:\WinPE_SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"#PowerShell Path

        # $VirtualRegistryPath_LabConfig = $VirtualRegistryPath_Setup + "\LabConfig"
        reg unload $VirtualRegistryPath_SYSTEM | Out-Null # Just in case...
        reg unload $VirtualRegistryPath_SOFTWARE | Out-Null # Just in case...
        Start-Sleep 1
        reg load $VirtualRegistryPath_SYSTEM $REG_System | Out-Null
        reg load $VirtualRegistryPath_SOFTWARE $REG_Software | Out-Null

        New-ItemProperty -Path $VirtualRegistryPath_location -Name "Value" -Value "Allow" -PropertyType String -Force
        New-ItemProperty -Path $VirtualRegistryPath_tzautoupdate -Name "start" -Value 3 -PropertyType DWord -Force



        Start-Sleep 1
        reg unload $VirtualRegistryPath_SYSTEM
        reg unload $VirtualRegistryPath_SOFTWARE
    }
    else {
        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location -Name Value -Value "Allow" -Type String | out-null
        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate -Name start -Value "3" -Type DWord | out-null
    }
}
Write-Host -ForegroundColor Green "[+] Set-DefaultProfilePersonalPref"
function Set-DefaultProfilePersonalPref {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
    Start-Sleep 1
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    #TaskBar Left / Hide Chat / Hide Widgets / Hide TaskView
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    New-ItemProperty -Path $Path -Name "TaskbarAl" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarMn" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarDa" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ShowTaskViewButton" -Value 0 -PropertyType Dword -Force | Out-Null

    #Disable Content Delivery
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-ItemProperty -Path $Path -Name "SystemPaneSuggestionsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SubscribedContentEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SoftLandingEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SilentInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "PreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "OemPreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "FeatureManagementEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ContentDeliveryAllowed" -Value 0 -PropertyType Dword -Force | Out-Null

    reg unload $VirtualRegistryPath_defaultuser | Out-Null
}

Write-Host -ForegroundColor Green "[+] Function Install-Nuget"
function Install-Nuget {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $NuGetClientSourceURL = 'https://nuget.org/nuget.exe'
        $NuGetExeName = 'NuGet.exe'
        $PSGetProgramDataPath = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetProgramDataPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
    
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
    
        $PSGetAppLocalPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetAppLocalPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
    }
    else {
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            #Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
        $InstalledModule = Get-PackageProvider -Name NuGet | Where-Object {$_.Version -ge '2.8.5.201'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] NuGet $([string]$InstalledModule.Version)"
        }
    }
}
Write-Host -ForegroundColor Green "[+] Function Install-PackageManagement"
function Install-PackageManagement {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
        if (-not $InstalledModule) {
            Write-Host -ForegroundColor Yellow "[-] Install PackageManagement 1.4.8.1"
            $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.8.1.nupkg"
            Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$env:TEMP\packagemanagement.1.4.8.1.zip"
            $null = New-Item -Path "$env:TEMP\1.4.8.1" -ItemType Directory -Force
            Expand-Archive -Path "$env:TEMP\packagemanagement.1.4.8.1.zip" -DestinationPath "$env:TEMP\1.4.8.1"
            $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path "$env:TEMP\1.4.8.1" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.8.1"
            Import-Module PackageManagement -Force -Scope Global
        }
    }
    else {
        $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider PowerShellGet -MinimumVersion 2.2.5"
            Install-PackageProvider -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Scope AllUsers | Out-Null
            Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        }
    
        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module PackageManagement -MinimumVersion 1.4.8.1"
            Install-Module -Name PackageManagement -MinimumVersion 1.4.8.1 -Force -Confirm:$false -Source PSGallery -Scope AllUsers
            Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        }
    
        Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PackageManagement $([string]$InstalledModule.Version)"
        }
        Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
        $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PowerShellGet $([string]$InstalledModule.Version)"
        }
    }
}
Write-Host -ForegroundColor Green "[+] Install-CMTrace"
function Install-CMTrace {

    <#
    Gary Blok - @gwblok - GARYTOWN.COM
    .Synopsis
      Proactive Remediation for CMTrace to be on endpoint

     .Description
      Creates Generic Shortcut in Start Menu
    #>
    $AppName = "CMTrace"
    $FileName = "CMTrace.exe"
    $InstallPath = "$env:windir\system32"
    $URL = "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/CMTrace.exe"
    $AppPath = "$InstallPath\$FileName"
    $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

    if ($env:SystemDrive -eq "C:"){ 
        Function New-AppIcon {
            param(
            [string]$SourceExePath = "$env:windir\system32\control.exe",
            [string]$ArgumentsToSourceExe,
            [string]$ShortCutName = "AppName"

            )
            #Build ShortCut Information

            $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
            $DestinationPath = "$ShortCutFolderPath\$($ShortCutName).lnk"
            Write-Output "Shortcut Creation Path: $DestinationPath"

            if ($ArgumentsToSourceExe){
                Write-Output "Shortcut = $SourceExePath -$($ArgumentsToSourceExe)"
            }
            Else {
                Write-Output "Shortcut = $SourceExePath"
            }
    

            #Create Shortcut
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($DestinationPath)
            $Shortcut.IconLocation = "$SourceExePath, 0"
            $Shortcut.TargetPath = $SourceExePath
            if ($ArgumentsToSourceExe){$Shortcut.Arguments = $ArgumentsToSourceExe}
            $Shortcut.Save()

            Write-Output "Shortcut Created"
        }

        if (!(Test-Path -Path $AppPath)){
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to $InstallPath"
            Copy-Item -Path $env:TEMP\$FileName -Destination $InstallPath -Force
            #Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
            if (Test-Path -Path $AppPath){
                Write-Output "Successfully Installed File"
                New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
            }
            else{Write-Output "Failed Extract"; exit 255}
        }
        else {
            Write-Output "$AppName Already Installed"
        }


        if (!(Test-Path "$ShortCutFolderPath\$($AppName).lnk")){
            New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
        }
    }
    else {
        if (!(Test-Path -Path $AppPath)){
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to $InstallPath"
            Copy-Item -Path $env:TEMP\$FileName -Destination $InstallPath -Force
            #Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
            if (Test-Path -Path $AppPath){
                Write-Output "Successfully Installed File"
                New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
            }
            else{Write-Output "Failed Install"; exit 255}
        }
        else {
            Write-Output "$AppName Already Installed"
        }

    }

}
Write-Host -ForegroundColor Green "[+] Function Set-LatestUpdatesASAPEnabled"
function Set-LatestUpdatesASAPEnabled {
    Write-Host "Enable 'Get the latest updates as soon as they’re available' Reg Value" -ForegroundColor DarkGray
    if ($env:SystemDrive -eq 'X:') {
        $WindowsPhase = 'WinPE'
    }
    if ($WindowsPhase -eq 'WinPE'){
        Invoke-Exe reg load HKLM\TempSOFTWARE "C:\Windows\System32\Config\SOFTWARE"
        Invoke-Exe reg add HKLM\TempSOFTWARE\Microsoft\WindowsUpdate\UX\Settings /V IsContinuousInnovationOptedIn /T REG_DWORD /D 1 /F
        Invoke-Exe reg unload HKLM\TempSOFTWARE
    }
    else {
        Invoke-Exe reg add HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings /V IsContinuousInnovationOptedIn /T REG_DWORD /D 1 /F
    }
}
Write-Host -ForegroundColor Green "[+] Function Set-APEnterprise"
function Set-APEnterprise {
    Install-Nuget
    Install-PackageManagement
    Install-script -name Get-WindowsAutoPilotInfo -Force
    Set-ExecutionPolicy Bypass -Force
    Get-WindowsAutopilotInfo -Online -GroupTag Enterprise -Assign
}

Write-Host -ForegroundColor Green "[+] Install-23H2EnablementPackage"
function Install-23H2EnablementPackage {
	Function Install-Update {
	    [CmdletBinding()]
	    Param (
	    [Parameter(Mandatory=$true)]
		$UpdatePath
	    )
	
	    $scratchdir = 'C:\OSDCloud\Temp'
	    if (!(Test-Path -Path $scratchdir)){
	        new-item -Path $scratchdir | Out-Null
	    }
	
	    if ($env:SystemDrive -eq "X:"){
	        $Process = "X:\Windows\system32\Dism.exe"
	        $DISMArg = "/Image:C:\ /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
	    }
	    else {
	        $Process = "C:\Windows\system32\Dism.exe"
	        $DISMArg = "/Online /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
	    }
	
	
	    Write-Output "Starting Process of $Process -ArgumentList $DismArg -Wait"
	    $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru
	    
	    return $DISM.ExitCode
	}
	
	
	$23H2EnablementCabURL = "https://raw.githubusercontent.com/gwblok/garytown/master/SoftwareUpdates/Windows11.0-kb5027397-x64.cab"
	Invoke-WebRequest -UseBasicParsing -Uri $23H2EnablementCabURL -OutFile "$env:TEMP\Windows11.0-kb5027397-x64.cab"
	
	if (Test-Path -Path "$env:TEMP\Windows11.0-kb5027397-x64.cab"){
	    Install-MSU -MSUPath "$env:TEMP\Windows11.0-kb5027397-x64.cab"
	}
}

#HP Dock Function
Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)

#HPIA Functions
Write-Host -ForegroundColor Green "[+] Function Get-HPIALatestVersion"
Write-Host -ForegroundColor Green "[+] Function Install-HPIA"
Write-Host -ForegroundColor Green "[+] Function Run-HPIA"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAXMLResult"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAJSONResult"

iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/HPIA/HPIA-Functions.ps1)


#Install-ModuleHPCMSL
Write-Host -ForegroundColor Green "[+] Function Install-ModuleHPCMSL"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Install-ModuleHPCMSL.ps1)


