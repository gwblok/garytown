$ScriptName = 'functions.garytown.com'
$ScriptVersion = '24.2.1.3'

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
Write-Host -ForegroundColor Green "[+] Function Get-MyComputerInfoBasic"
Function Get-MyComputerInfoBasic {
    Function Convert-FromUnixDate ($UnixDate) {
        [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
    }
    Function Get-TPMVer {
    $Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
    if ($Manufacturer -match "HP"){
        if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2")
            {
            $versionInfo = (Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersionInfo
            $verMaj      = [Convert]::ToInt32($versionInfo[0..1] -join '', 16)
            $verMin      = [Convert]::ToInt32($versionInfo[2..3] -join '', 16)
            $verBuild    = [Convert]::ToInt32($versionInfo[4..6] -join '', 16)
            $verRevision = 0
            [version]$ver = "$verMaj`.$verMin`.$verBuild`.$verRevision"
            Write-Output "TPM Verion: $ver | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
            }
        else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
    }

    else    {
        if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2"){
            Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
            }
        else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
        }
    }

    $BIOSInfo = Get-WmiObject -Class 'Win32_Bios'

    # Get the current BIOS release date and format it to datetime
    $CurrentBIOSDate = [System.Management.ManagementDateTimeConverter]::ToDatetime($BIOSInfo.ReleaseDate).ToUniversalTime()

    $Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
    $ManufacturerBaseBoard = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Manufacturer
    $ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
    if ($ManufacturerBaseBoard -eq "Intel Corporation")
        {
        $ComputerModel = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
        }
    $HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    $Serial = (Get-WmiObject -class:win32_bios).SerialNumber
    $LenovoName = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version
    $cpuDetails = @(Get-WmiObject -Class Win32_Processor)[0]

    Write-Output "Computer Name: $env:computername"
    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $InstallDate_CurrentOS = Convert-FromUnixDate $CurrentOSInfo.GetValue('InstallDate')
    $WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
    if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}
    $BuildUBR_CurrentOS = $($CurrentOSInfo.GetValue('CurrentBuild'))+"."+$($CurrentOSInfo.GetValue('UBR'))
    Write-Output "Windows $WindowsRelease | $BuildUBR_CurrentOS | Installed: $InstallDate_CurrentOS"

    Write-Output "Computer Manufacturer: $Manufacturer"
    Write-Output "Computer Model: $ComputerModel"
    Write-Output "Serial: $Serial"
    if ($Manufacturer -like "H*"){Write-Output "Computer Product Code: $HPProdCode"}
    if ($Manufacturer -like "Le*"){Write-Output "Computer Friendly Name: $LenovoName"}
    Write-Output $cpuDetails.Name
    Write-Output "Current BIOS Level: $($BIOSInfo.SMBIOSBIOSVersion) From Date: $CurrentBIOSDate"
    Get-TPMVer
    Write-Output "Time Zone: $(Get-TimeZone)"
    $Locale = Get-WinSystemLocale
    if ($Locale -ne "en-US"){Write-Output "WinSystemLocale: $locale"}
    Get-WmiObject win32_LogicalDisk -Filter "DeviceID='C:'" | % { $FreeSpace = $_.FreeSpace/1GB -as [int] ; $DiskSize = $_.Size/1GB -as [int] }



    Write-Output "DiskSize = $DiskSize, FreeSpace = $Freespace"
    #Get Volume Infomration
    try {$SecureBootStatus = Confirm-SecureBootUEFI}
    catch {}
    if ($SecureBootStatus -eq $false -or $SecureBootStatus -eq $true){
        $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
        $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
        $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
        $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
        $FreeMB = [MATH]::Round(($SystemVolume).SizeRemaining /1MB)
        Write-Output "Systvem Volume FreeSpace = $FreeMB MB"
    }

    $Disk = Get-Disk | Where-Object {$_.BusType -ne "USB"}
    write-output "$($Disk.Model) $($Disk.BusType)"
    

    $MemorySize = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory/1MB)
    Write-Output "Memory size = $MemorySize MB"
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
Write-Host -ForegroundColor Green "[+] Function Set-DOPoliciesGPORegistry"
Function Set-DOPoliciesGPORegistry {
    $DOReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (!(Test-Path -Path $DOReg)){
        New-Item -Path $DOReg -ItemType Directory
    }
    New-ItemProperty -Path $DOReg -Name "DOAbsoluteMaxCacheSize" -PropertyType dword -Value '0000001e' -Force
    New-ItemProperty -Path $DOReg -Name "DODelayBackgroundDownloadFromHttp" -PropertyType dword -Value '00000258' -Force
    New-ItemProperty -Path $DOReg -Name "DODelayForegroundDownloadFromHttp" -PropertyType dword -Value '00000258' -Force
    New-ItemProperty -Path $DOReg -Name "DOMaxCacheAge" -PropertyType dword -Value '00000000' -Force
    New-ItemProperty -Path $DOReg -Name "DOMaxForegroundDownloadBandwidth" -PropertyType dword -Value '00000a00' -Force
    New-ItemProperty -Path $DOReg -Name "DODownloadMode" -PropertyType dword -Value '00000001' -Force
    New-ItemProperty -Path $DOReg -Name "DOMinBackgroundQos" -PropertyType dword -Value '00000040' -Force
    New-ItemProperty -Path $DOReg -Name "DOMinRAMAllowedToPeer" -PropertyType dword -Value '00000002' -Force
    New-ItemProperty -Path $DOReg -Name "DOMinFileSizeToCache" -PropertyType dword -Value '00000001' -Force
}
Write-Host -ForegroundColor Green "[+] Function Set-Win11ReqBypassRegValues"
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

Write-Host -ForegroundColor Green "[+] Function Start-WindowsUpdate"
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

Write-Host -ForegroundColor Green "[+] Function Start-WindowsUpdateDriver"
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

Write-Host -ForegroundColor Green "[+] Function Enable-AutoZimeZoneUpdate"
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
    Write-Output "Running in $WindowsPhase"
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

	    $REG_defaultuser = "c:\users\default\ntuser.dat"
    	$VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    	$VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    	reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
    	Start-Sleep 1
    	reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null
    	#Enable Location for Auto Time Zone
    	$Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    	New-ItemProperty -Path $Path -Name "Value" -Value Allow -PropertyType String -Force | Out-Null
    
    	reg unload $VirtualRegistryPath_defaultuser | Out-Null     
    }
    else {
        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location -Name Value -Value "Allow" -Type String | out-null
	    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location -Name Value -Value "Allow" -Type String | out-null
        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate -Name start -Value "3" -Type DWord | out-null
    }
}
Write-Host -ForegroundColor Green "[+] Function Set-DefaultProfilePersonalPref"
function Set-DefaultProfilePersonalPref {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    if (Test-Path -Path $VirtualRegistryPath_software){
        reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
        Start-Sleep 1
    }
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

    #Enable Location for Auto Time Zone
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path $Path -Name "Value" -Value Allow -PropertyType String -Force | Out-Null
    Start-Sleep -s 1
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
            Write-Output "$AppName already installed here: $AppPath"
        }
        if (Test-Path "C:\Windows\System32\$FileName"){
            Write-Output "$AppName already installed here: C:\Windows\System32\$FileName"
        }
        else{
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to C:\Windows\System32\$FileName"
            Copy-Item -Path $env:TEMP\$FileName -Destination "C:\Windows\System32\$FileName" -Force
            if (Test-Path -Path "C:\Windows\System32\$FileName"){
                Write-Output "Successfully Installed File"
            }
            else{Write-Output "Failed Install"; exit 255}
               
        }
    }
}
Write-Host -ForegroundColor Green "[+] Function Invoke-UpdateScanMethodMSStore"
Function Invoke-UpdateScanMethodMSStore {
    try {
        $AppMan01 = Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01'
        try {
            Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01'| Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
        }
        catch {
            Write-Output "Failed to trigger Updates"
        }
    }
    catch{
        Write-Output "Failed to get CimInstance"
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

Write-Host -ForegroundColor Green "[+] Function Install-23H2EnablementPackage"
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
	    Install-Update -UpdatePath "$env:TEMP\Windows11.0-kb5027397-x64.cab"
	}
}
Write-Host -ForegroundColor Green "[+] Function Install-BuildUpdatesFromOSCloudUSB - Coming to OSDCloud native in 21.11.XX"
function Install-BuildUpdatesFromOSCloudUSB {
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
    $BuildNumber = (Get-UBR).split(".")[2]
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $UpdatesPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS\Updates"
    $MSUUpdates = Get-ChildItem -Path $UpdatesPath -Recurse | Where-Object {$_.Name -match ".msu" -or $_.Name -match ".cab"}
    $BuildUpdates = $MSUUpdates | Where-Object {$_.fullname -match "$BuildNumber"}

write-host "Looking for updates here: $UpdatesPath for Build: $BuildNumber"
    if ($BuildUpdates){
        Write-Output "Current OS UBR: $(Get-UBR)"
        Write-Host " Found thse Updates: "
        foreach ($Update in $BuildUpdates){
            $Update.FullName
        }
        Write-Host "Starting DISM Update Process"
        foreach ($Update in $BuildUpdates){
            Write-Host "Installing Update: $($Update.Name)"
            Install-Update -UpdatePath $Update.FullName
        }
        Write-Output "Current OS UBR: $(Get-UBR)"
    }
    else {
	write-host "No Updates found for $BuildNumber"
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

Write-Host -ForegroundColor Green "[+] Function Invoke-HPAnalyzer"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPDriverUpdate"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Invoke-HPDriverUpdate.ps1)

Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-OSDCloudIPU"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudIPU/Invoke-OSDCloudIPU.ps1)

Write-Host -ForegroundColor Green "[+] Function Manage-HPBiosSettings"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-Debloat"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Debloat.ps1)

Write-Host -ForegroundColor Green "[+] Function Set-ThisPC"
function Set-ThisPC {iex (irm https://raw.githubusercontent.com/gwblok/garytown/f64b267ba11c3a632ee0d19656875f93b715a989/OSD/CloudOSD/Set-ThisPC.ps1)}

Write-Host -ForegroundColor Green "[+] Function Get-NativeMatchineImage"
Function Get-NativeMatchineImage {
#Code from https://github.com/rweijnen/Posh-Snippets/blob/master/PoshWow64ApiSet
$source = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.ComponentModel;

public static class WinApi
{
    public const ushort IMAGE_FILE_MACHINE_UNKNOWN = 0;
    public const ushort IMAGE_FILE_MACHINE_TARGET_HOST = 0x0001; // Useful for indicating we want to interact with the host and not a WoW guest.
    public const ushort IMAGE_FILE_MACHINE_I386 = 0x014c; // Intel 386.
    public const ushort IMAGE_FILE_MACHINE_R3000 = 0x0162; // MIPS little-endian, = 0x160 big-endian
    public const ushort IMAGE_FILE_MACHINE_R4000 = 0x0166; // MIPS little-endian
    public const ushort IMAGE_FILE_MACHINE_R10000 = 0x0168; // MIPS little-endian
    public const ushort IMAGE_FILE_MACHINE_WCEMIPSV2 = 0x0169; // MIPS little-endian WCE v2
    public const ushort IMAGE_FILE_MACHINE_ALPHA = 0x0184; // Alpha_AXP
    public const ushort IMAGE_FILE_MACHINE_SH3 = 0x01a2; // SH3 little-endian
    public const ushort IMAGE_FILE_MACHINE_SH3DSP = 0x01a3;
    public const ushort IMAGE_FILE_MACHINE_SH3E = 0x01a4; // SH3E little-endian
    public const ushort IMAGE_FILE_MACHINE_SH4 = 0x01a6; // SH4 little-endian
    public const ushort IMAGE_FILE_MACHINE_SH5 = 0x01a8; // SH5
    public const ushort IMAGE_FILE_MACHINE_ARM = 0x01c0; // ARM Little-Endian
    public const ushort IMAGE_FILE_MACHINE_THUMB = 0x01c2; // ARM Thumb/Thumb-2 Little-Endian
    public const ushort IMAGE_FILE_MACHINE_ARMNT = 0x01c4; // ARM Thumb-2 Little-Endian
    public const ushort IMAGE_FILE_MACHINE_AM33 = 0x01d3;
    public const ushort IMAGE_FILE_MACHINE_POWERPC = 0x01F0; // IBM PowerPC Little-Endian
    public const ushort IMAGE_FILE_MACHINE_POWERPCFP = 0x01f1;
    public const ushort IMAGE_FILE_MACHINE_IA64 = 0x0200; // Intel 64
    public const ushort IMAGE_FILE_MACHINE_MIPS16 = 0x0266; // MIPS
    public const ushort IMAGE_FILE_MACHINE_ALPHA64 = 0x0284; // ALPHA64
    public const ushort IMAGE_FILE_MACHINE_MIPSFPU = 0x0366; // MIPS
    public const ushort IMAGE_FILE_MACHINE_MIPSFPU16 = 0x0466; // MIPS
    public const ushort IMAGE_FILE_MACHINE_AXP64 = IMAGE_FILE_MACHINE_ALPHA64;
    public const ushort IMAGE_FILE_MACHINE_TRICORE = 0x0520; // Infineon
    public const ushort IMAGE_FILE_MACHINE_CEF = 0x0CEF;
    public const ushort IMAGE_FILE_MACHINE_EBC = 0x0EBC; // EFI Byte Code
    public const ushort IMAGE_FILE_MACHINE_AMD64 = 0x8664; // AMD64 (K8)
    public const ushort IMAGE_FILE_MACHINE_M32R = 0x9041; // M32R little-endian
    public const ushort IMAGE_FILE_MACHINE_ARM64 = 0xAA64; // ARM64 Little-Endian
    public const ushort IMAGE_FILE_MACHINE_CEE = 0xC0EE;

    public const UInt32 S_OK = 0;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern UInt32 IsWow64GuestMachineSupported(ushort WowGuestMachine, out bool MachineIsSupported);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool IsWow64Process2(IntPtr hProcess, out ushort pProcessMachine, out ushort pNativeMachine);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr GetCurrentProcess();

    public static string MachineTypeToStr(ushort MachineType)
    {
        switch (MachineType)
        {
            case IMAGE_FILE_MACHINE_UNKNOWN:
                return "IMAGE_FILE_MACHINE_UNKNOWN";
            case IMAGE_FILE_MACHINE_TARGET_HOST:
                return "IMAGE_FILE_MACHINE_TARGET_HOST";
            case IMAGE_FILE_MACHINE_I386:
                return "IMAGE_FILE_MACHINE_I386";
            case IMAGE_FILE_MACHINE_R3000:
                return "IMAGE_FILE_MACHINE_R3000";
            case IMAGE_FILE_MACHINE_R4000:
                return "IMAGE_FILE_MACHINE_R4000";
            case IMAGE_FILE_MACHINE_R10000:
                return "IMAGE_FILE_MACHINE_R10000";
            case IMAGE_FILE_MACHINE_WCEMIPSV2:
                return "IMAGE_FILE_MACHINE_WCEMIPSV2";
            case IMAGE_FILE_MACHINE_ALPHA:
                return "IMAGE_FILE_MACHINE_ALPHA";
            case IMAGE_FILE_MACHINE_SH3:
                return "IMAGE_FILE_MACHINE_SH3";
            case IMAGE_FILE_MACHINE_SH3DSP:
                return "IMAGE_FILE_MACHINE_SH3DSP";
            case IMAGE_FILE_MACHINE_SH3E:
                return "IMAGE_FILE_MACHINE_SH3E";
            case IMAGE_FILE_MACHINE_SH4:
                return "IMAGE_FILE_MACHINE_SH4";
            case IMAGE_FILE_MACHINE_SH5:
                return "IMAGE_FILE_MACHINE_SH5";
            case IMAGE_FILE_MACHINE_ARM:
                return "IMAGE_FILE_MACHINE_ARM";
            case IMAGE_FILE_MACHINE_THUMB:
                return "IMAGE_FILE_MACHINE_THUMB";
            case IMAGE_FILE_MACHINE_ARMNT:
                return "IMAGE_FILE_MACHINE_ARMNT";
            case IMAGE_FILE_MACHINE_AM33:
                return "IMAGE_FILE_MACHINE_AM33";
            case IMAGE_FILE_MACHINE_POWERPC:
                return "IMAGE_FILE_MACHINE_POWERPC";
            case IMAGE_FILE_MACHINE_POWERPCFP:
                return "IMAGE_FILE_MACHINE_POWERPCFP";
            case IMAGE_FILE_MACHINE_IA64:
                return "IMAGE_FILE_MACHINE_IA64";
            case IMAGE_FILE_MACHINE_MIPS16:
                return "IMAGE_FILE_MACHINE_MIPS16";
            case IMAGE_FILE_MACHINE_ALPHA64:
                return "IMAGE_FILE_MACHINE_ALPHA64";
            case IMAGE_FILE_MACHINE_MIPSFPU:
                return "IMAGE_FILE_MACHINE_MIPSFPU";
            case IMAGE_FILE_MACHINE_MIPSFPU16:
                return "IMAGE_FILE_MACHINE_MIPSFPU16";
            case IMAGE_FILE_MACHINE_TRICORE:
                return "IMAGE_FILE_MACHINE_TRICORE";
            case IMAGE_FILE_MACHINE_CEF:
                return "IMAGE_FILE_MACHINE_CEF";
            case IMAGE_FILE_MACHINE_EBC:
                return "IMAGE_FILE_MACHINE_EBC";
            case IMAGE_FILE_MACHINE_AMD64:
                return "IMAGE_FILE_MACHINE_AMD64";
            case IMAGE_FILE_MACHINE_M32R:
                return "IMAGE_FILE_MACHINE_M32R";
            case IMAGE_FILE_MACHINE_ARM64:
                return "IMAGE_FILE_MACHINE_ARM64";
            case IMAGE_FILE_MACHINE_CEE:
                return "IMAGE_FILE_MACHINE_CEE";
            default:
                return "Unknown Machine Type";
        }
    }
}
"@

Add-Type $source

$ReturnTable = New-Object -TypeName PSObject


[bool]$MachineIsSupported = $false
$hr = [WinApi]::IsWow64GuestMachineSupported([WinApi]::IMAGE_FILE_MACHINE_I386, [ref]$MachineIsSupported)
if ($hr -eq [WinApi]::S_OK){
    #$ReturnTable | Add-Member -MemberType NoteProperty -Name "IsWow64GuestMachineSupported IMAGE_FILE_MACHINE_I386" -Value $MachineIsSupported -Force	
}

[UInt16]$processMachine = 0;
[UInt16]$nativeMachine = 0;
$bResult = [WinApi]::IsWow64Process2([WinApi]::GetCurrentProcess(), [ref]$processMachine, [ref]$nativeMachine);
if ($bResult){
    $Value = $([WinApi]::MachineTypeToStr($nativeMachine))
    $Value = $Value.Split("_") | Select-Object -Last 1
    $ReturnTable | Add-Member -MemberType NoteProperty -Name "NativeMachine" -Value $Value -Force

    $Value = $([WinApi]::MachineTypeToStr($processMachine))
    $Value = $Value.Split("_") | Select-Object -Last 1
    $ReturnTable | Add-Member -MemberType NoteProperty -Name "ProcessMachine" -Value $Value -Force
}

return $ReturnTable
}

