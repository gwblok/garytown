$ScriptName = 'functions.garytown.com'
$ScriptVersion = '25.1.7.1'
Set-ExecutionPolicy Bypass -Force

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Start-DISMFromOSDCloudUSB"
Function Test-DISMFromOSDCloudUSB {
    [CmdletBinding()]
    param (

        [Parameter()]
        [System.String]
        $PackageID
    )
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    if ($OSDCloudUSB){
        $OSDCloudDriveLetter = $OSDCloudUSB.DriveLetter
    }
    $MappedDrives = (Get-CimInstance -ClassName Win32_MappedLogicalDisk).DeviceID | Select-Object -Unique
    if ($MappedDrives){
        ForEach ($MappedDrive in $MappedDrives){
            if (Test-Path -Path "$MappedDrive\OSDCloud"){
                $OSDCloudDriveLetter = $MappedDrive.replace(":","")
            }
        }
    }
    if ($OSDCloudDriveLetter){
        $ComputerProduct = (Get-MyComputerProduct)
        if (!($PackageID)){
            $PackageID = $DriverPack.PackageID
            $DriverPack = Get-OSDCloudDriverPack -Product $ComputerProduct
        }
        $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
        if ($ComputerManufacturer -match "Samsung"){$ComputerManufacturer = "Samsung"}
        $DriverPathProduct = "$($OSDCloudDriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
        $DriverPathPackageID = "$($OSDCloudDriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$PackageID"
        if ($PackageID){  
            Write-Host "Testing Paths:"
            Write-Host "  $DriverPathProduct"
            Write-Host "  $DriverPathPackageID"
        }
        else {
            Write-Host "Testing Path:"
            Write-Host "  $DriverPathProduct"
        }
        if (Test-Path $DriverPathProduct){Return $true}
        elseif (Test-Path $DriverPathPackageID){Return $true}
        else { Return $false}
    }
    else{
        Write-Host "NO OSDCloud USB Found"
        return $false
    }
}
Function Start-DISMFromOSDCloudUSB {
    [CmdletBinding()]
    param (

        [Parameter()]
        [System.String]
        $PackageID
    )
    if ($env:SystemDrive -eq 'X:') {
        $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
        if ($OSDCloudUSB){
            $OSDCloudDriveLetter = $OSDCloudUSB.DriveLetter
        }
        $MappedDrives = (Get-CimInstance -ClassName Win32_MappedLogicalDisk).DeviceID | Select-Object -Unique
        if ($MappedDrives){
            ForEach ($MappedDrive in $MappedDrives){
                if (Test-Path -Path "$MappedDrive\OSDCloud"){
                    $OSDCloudDriveLetter = $MappedDrive.replace(":","")
                }
            }
        }
        if ($OSDCloudDriveLetter){
            $ComputerProduct = (Get-MyComputerProduct)
            if (!($PackageID)){
                $DriverPack = Get-OSDCloudDriverPack -Product $ComputerProduct
                if ($DriverPack){
                    $PackageID = $DriverPack.PackageID
                }
            }
            $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
            if ($ComputerManufacturer -match "Samsung"){$ComputerManufacturer = "Samsung"}
            $DriverPathProduct = "$($OSDCloudDriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
            if ($PackageID){
                $DriverPathPackageID = "$($OSDCloudDriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$PackageID"
            }
    
            Write-Host "Checking locations for Drivers" -ForegroundColor Green
            if ($PackageID){
                if (Test-Path $DriverPathPackageID){$DriverPath = $DriverPathPackageID}
            }
            if (Test-Path $DriverPathProduct){$DriverPath = $DriverPathProduct}
            if (Test-Path $DriverPath){
                Write-Host "Found Drivers: $DriverPath" -ForegroundColor Green
                Write-Host "Starting DISM of drivers while Offline" -ForegroundColor Green
                $DismPath = "$env:windir\System32\Dism.exe"
                $DismProcess = Start-Process -FilePath $DismPath -ArgumentList "/image:c:\ /Add-Driver /driver:`"$($DriverPath)`" /recurse" -Wait -PassThru
                Write-Host "Finished Process with Exit Code: $($DismProcess.ExitCode)"
            }
        }
        
    }
    else {
        Write-Output "Skipping Start-DISMFromOSDCloudUSB Function, not running in WinPE"
    }
}
Write-Host -ForegroundColor Green "[+] Function Get-HyperVName"
function Get-HyperVName {
    [CmdletBinding()]
    param ()
    if ($env:SystemDrive -eq 'X:'){
        Write-host "Unable to get HyperV Name in WinPE"
    }
    else{
        if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation")){
            $HyperVName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        }
    return $HyperVName
    }
}

Write-Host -ForegroundColor Green "[+] Function Get-HyperVHostName"
function Get-HyperVHostName {
    [CmdletBinding()]
    param ()
    if ($env:SystemDrive -eq 'X:'){
        Write-host "Unable to get HyperV Name in WinPE"
    }
    else{
        if (((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine") -and ((Get-CimInstance Win32_ComputerSystem).Manufacturer -eq "Microsoft Corporation")){
            $HyperVHostName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name "HostName" -ErrorAction SilentlyContinue
        }
    return $HyperVHostName
    }

}

Write-Host -ForegroundColor Green "[+] Function Set-HyperVName"
function Set-HyperVName {
    [CmdletBinding()]
    param ()
    $HyperVName = Get-HyperVName
    Write-Output "Renaming Computer to $HyperVName"
    Rename-Computer -NewName $HyperVName -Force 
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
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Start-WindowsUpdate.ps1)

Write-Host -ForegroundColor Green "[+] Functions for HP TPM"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Get-HPTPMDetermine.ps1)

Write-Host -ForegroundColor Green "[+] Function Start-WindowsUpdateDriver"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Start-WindowsUpdateDrivers.ps1)

Write-Host -ForegroundColor Green "[+] Function Enable-AutoTimeZoneUpdate"
Function Enable-AutoTimeZoneUpdate {

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

Write-Host -ForegroundColor Green "[+] Install-WMIExplorer"
function Install-WMIExplorer {
	iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Intune/Install-WMIExplorer-Remediate.ps1)
}
Write-Host -ForegroundColor Green "[+] Install-ZoomIt"
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/Install-ZoomIt.ps1)

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
function Set-APHub {
    Install-Nuget
    Install-PackageManagement
    Install-script -name Get-WindowsAutoPilotInfo -Force
    Set-ExecutionPolicy Bypass -Force
    Get-WindowsAutopilotInfo -Online -GroupTag HUB -Assign
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

#Updating the OSD Module on the Offline OS from the one installed in WinPE - Used in testing to copy over updates not yet in the Gallery Module
Write-Host -ForegroundColor Green "[+] Function Update-OfflineOSDModuleFromWinPEVersion"
Function Update-OfflineOSDModuleFromWinPEVersion {
    #Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
    $ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
    import-module "$ModulePath\OSD.psd1" -Force

    #Used in Testing "Beta Gary Modules which I've updated on the USB Stick"
    $OfflineModulePath = (Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
    write-output "Updating $OfflineModulePath using $ModulePath"
    copy-item "$ModulePath\*" "$OfflineModulePath"  -Force -Recurse
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

#HP CMSL WinPE replacement
Write-Host -ForegroundColor Green "[+] Function Get-HPOSSupport"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqListLatest"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqItems"
Write-Host -ForegroundColor Green "[+] Function Get-HPDriverPackLatest"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Test-HPIASupport.ps1)

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
function Set-ThisPC {iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Set-ThisPC.ps1)}

Write-Host -ForegroundColor Green "[+] Function Get-WindowsESDFileInfo"
function Get-WindowsESDFileInfo {iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/Get-WindowsESDFileInfo.ps1)}

Write-Host -ForegroundColor Green "[+] Function Check-ComplianceKB5025885"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/ConfigMgr/Baselines/CVE-2023-24932/KB5025885-CheckCompliance.ps1)

if ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer -match "Lenovo"){
	Write-Host -ForegroundColor Green "[+] Function Install-LenovoDMM"
    function Install-LenovoDMM {
        $LenovoDMMURL = "https://download.lenovo.com/cdrt/tools/ldmm_1.0.0.zip"
        Invoke-WebRequest -UseBasicParsing -Uri $LenovoDMMURL -OutFile "$env:TEMP\ldmm.zip"
        Expand-Archive -Path "$env:TEMP\ldmm.zip" -DestinationPath "$env:ProgramFiles\WindowsPowerShell\Modules" -Force
        Import-Module LnvDeviceManagement -Force -Verbose
    }
    	Write-Host -ForegroundColor Green "[+] Function Install-LenovoSystemUpdater"
	iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Install-LenovoApps.ps1)
}
if ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer -match "Dell"){
	Write-Host -ForegroundColor Green "[+] Function OSDCloud-DCU..."
	iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1)
}

write-host "Branch Cache 2Pint Scripts" -ForegroundColor Cyan

Write-Host -ForegroundColor Green "[+] Function Setup-BranchCache"
function Setup-BranchCache {
	iex (irm 'https://raw.githubusercontent.com/2pintsoftware/BranchCache/refs/heads/master/ConfigMgr%20Configuration%20Item%20(CI)%20to%20Enable%20and%20Tune%20BranchCache/Source/MAIN_REMEDIATE.ps1')
 	iex (irm 'https://raw.githubusercontent.com/2pintsoftware/BranchCache/refs/heads/master/ConfigMgr%20Configuration%20Item%20(CI)%20to%20Enable%20and%20Tune%20BranchCache/Source/CacheSize_REMEDIATE.ps1')
 }


