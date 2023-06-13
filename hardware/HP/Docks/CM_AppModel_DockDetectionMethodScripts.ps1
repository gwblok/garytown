#This is just a group of snips used for the detection methods:


########################################################################################
#Thunderbolt G2
#Keep this updated based on the Firmware Version you're installing
#[version]$UpdateVersion = '1.0.71.1'
[string]$SoftPaqNumber = 'sp143977' #Format sp144502

<#  Not useful in hotelling situations, can provide false postitives.
#Check Registry for Values (If Firmware Updater ran in past on this device)
$RegPath = 'HKLM:\SOFTWARE\hp\HP Firmware Installer\HP Thunderbolt Dock G2'
if (Test-Path -Path $RegPath){
    $TBG2 = get-item $RegPath
    [version]$InstalledVersion = $TBG2.GetValue('InstalledPackageVersion')
    if ($InstalledVersion -eq $UpdateVersion){
        Write-Output $InstalledVersion
        exit
    }
}
#>

#Keep this updated based on the softpaq number you're installing
$FirmwareUpdater = "C:\swsetup\dockfirmware\$SoftPaqNumber\HPFirmwareInstaller.exe"
if (Test-Path $FirmwareUpdater){ #Run Firmware Check to determine if Firmware Current
    $FirmwareCheck = Start-Process -FilePath $FirmwareUpdater -ArgumentList "-c" -PassThru -NoNewWindow -Wait
    if ($FirmwareCheck.ExitCode -eq 0){
        Write-Output "Firmware is Current"
    }
}




#########################################################################################
#Thunderbolt G4
#Keep this updated based on the Firmware Version you're installing
[string]$UpdateVersion = '1.4.16.0'


$FirmwareLog = "C:\Windows\Temp\HPFirmwareInstaller.log"
$namespace = "ROOT\HP\InstrumentedServices\v1"
$classname = "HP_DockAccessory"
$VersionFromWMI = Get-CimInstance -Namespace $namespace  -ClassName $classname
if ($VersionFromWMI.FirmwarePackageVersion -eq $UpdateVersion){
    Write-Output "$UpdateVersion Installed"
}
else {
    if (Test-Path -Path $FirmwareLog){
        $UpdateLogInfo = Get-Content -Path $FirmwareLog
        [String]$NewVersion = $UpdateLogInfo | Select-String -Pattern 'New Version:' -SimpleMatch
        if($NewVersion -match $UpdateVersion){
            if ($UpdateLogInfo | Select-String -Pattern 'Install SUCCESS' -SimpleMatch){
            Write-Output "$UpdateVersion Staged"
            }
        }
    }
} 

#########################################################################################
#USB-C Dock G5
#Keep this updated based on the Firmware Version you're installing
[string]$UpdateVersion = '1.0.18.0'


$FirmwareLog = "C:\Windows\Temp\HPFirmwareInstaller.log"
$namespace = "ROOT\HP\InstrumentedServices\v1"
$classname = "HP_DockAccessory"
$VersionFromWMI = Get-CimInstance -Namespace $namespace  -ClassName $classname
if ($VersionFromWMI.FirmwarePackageVersion -eq $UpdateVersion){
    Write-Output "$UpdateVersion Installed"
}
else {
    if (Test-Path -Path $FirmwareLog){
        $UpdateLogInfo = Get-Content -Path $FirmwareLog
        [String]$NewVersion = $UpdateLogInfo | Select-String -Pattern 'New Version:' -SimpleMatch
        if($NewVersion -match $UpdateVersion){
            if ($UpdateLogInfo | Select-String -Pattern 'Install SUCCESS' -SimpleMatch){
            Write-Output "$UpdateVersion Staged"
            }
        }
    }
} 

#########################################################################################
#USB-C Dock G5 Essentials
#Keep this updated based on the Firmware softpaq you're installing
[string]$SoftPaqNumber = 'sp144502' #Format sp144502

$FirmwareUpdater = "C:\swsetup\dockfirmware\$SoftPaqNumber\HPFirmwareInstaller.exe"

if (Test-Path $FirmwareUpdater){ #Run Firmware Check to determine if Firmware Current
    $FirmwareCheck = Start-Process -FilePath $FirmwareUpdater -ArgumentList "-c" -PassThru -NoNewWindow -Wait
    if ($FirmwareCheck.ExitCode -eq 0){
        Write-Output "Firmware is Current"
    }
}


#########################################################################################
#USB-C/A Universal Dock G2
#Keep this updated based on the Firmware Version you're installing
[string]$UpdateVersion = '1.1.18.0'


$FirmwareLog = "C:\Windows\Temp\HPFirmwareInstaller.log"
$namespace = "ROOT\HP\InstrumentedServices\v1"
$classname = "HP_DockAccessory"
$VersionFromWMI = Get-CimInstance -Namespace $namespace  -ClassName $classname
if ($VersionFromWMI.FirmwarePackageVersion -eq $UpdateVersion){
    Write-Output "$UpdateVersion Installed"
}
else {
    if (Test-Path -Path $FirmwareLog){
        $UpdateLogInfo = Get-Content -Path $FirmwareLog
        [String]$NewVersion = $UpdateLogInfo | Select-String -Pattern 'New Version:' -SimpleMatch
        if($NewVersion -match $UpdateVersion){
            if ($UpdateLogInfo | Select-String -Pattern 'Install SUCCESS' -SimpleMatch){
            Write-Output "$UpdateVersion Staged"
            }
        }
    }
} 



