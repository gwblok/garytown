# Gary Blok | @gwblok | Recast Software
# Requies HPCMSL already loaded on your HP Devices... I have other scripts on Github that will do that via a Baseline

$ErrorActionPreference = "SilentlyContinue"

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model


Function Restart-ByPassComputerCM {

$time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
$Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;

$BLStatus = (Get-BitLockerVolume -ErrorAction SilentlyContinue).ProtectionStatus | Out-Null
if ($BLStatus -eq "On"){
    $MountPoint = (Get-BitLockerVolume).MountPoint  | Out-Null
    $Suspend = Suspend-BitLocker -MountPoint $MountPoint -RebootCount 1  | Out-Null
    }

$CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
} 


if ($Manufacturer -match "H")
    {
    Import-Module -Global -Name HPCMSL -ErrorAction SilentlyContinue
    $HPCMSLInfo = Get-Module -Name HPCMSL
    if ($HPCMSLInfo){
        [version]$BIOSVersion = Get-HPBIOSVersion
        [version]$LatestHPBIOSVersion = (Get-HPBIOSUpdates -Latest).ver

        if ($BIOSVersion -lt $LatestHPBIOSVersion)
            {
            Write-Host "$ComputerModel Update $BIOSVersion to $LatestHPBIOSVersion" -ForegroundColor Yellow
            $BIOSPassSet = Get-HPBIOSSetupPasswordIsSet
                if ($BIOSPassSet)
                    {
                    $Process = Get-HPBIOSUpdates -Flash -Quiet -YES -Password 'Passw0rd'
                    }
                else
                    {
                    $Process = Get-HPBIOSUpdates -Flash -Quiet -YES
                    }
            Restart-ByPassComputerCM
            }
        else
            {
            Write-Host "$ComputerModel Already Current: $BIOSVersion" -ForegroundColor Green
           }
        
        }
    else {
        Write-Output "Did not find HPCMSL loaded on this Machine"
        }
    }
else
    {
    Write-Output "This is not a HP Device | $Manufacturer $ComputerModel"
    }
