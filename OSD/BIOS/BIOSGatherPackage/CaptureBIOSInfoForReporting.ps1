$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$CMSL = $tsenv.Value("CMSL01")
$BIOS = Get-WmiObject -Class 'Win32_Bios'
$RegistryPathWaaS = "HKLM:SOFTWARE\WaaS"
$RegistryPathBIOS = "HKLM:SOFTWARE\WaaS\BIOS"
if (!(Test-path -Path $RegistryPathWaaS)){New-Item -Path $RegistryPathWaaS | Out-Null}
if (!(Test-path -Path $RegistryPathBIOS)){New-Item -Path $RegistryPathBIOS | Out-Null}


function Get-Manufacturer {

    $cs = gwmi -Class 'Win32_ComputerSystem'

    If ($cs.Manufacturer -eq 'HP' -or $cs.Manufacturer -eq 'Hewlett-Packard') {
        $Manufacturer = 'HP'
    }
    elseif ($cs.Manufacturer -eq 'Dell Inc.') {
        $Manufacturer = 'Dell'
    }
    else {
        $Manufacturer = $cs.Manufacturer
    }
    return $Manufacturer
}

function Get-HPBIOSVer {
    [cmdletbinding()]
    param (
        $CMSL
        )
    $BIOS = Get-WmiObject -Class 'Win32_Bios'
    $Manufacturer = Get-Manufacturer
    if ($Manufacturer -eq "Dell")
        {
        $CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
        return $CurrentBIOSVersion
        }

    if ($Manufacturer -eq "HP")
        {
        # Get the file path to HP.Firmware.psm1
        try {$HPBiosVersion = get-hpbiosversion}
        catch {$HPBiosVersion = $null}

        if ($HPBiosVersion)
            {
            return $HPBiosVersion
            }
        else
            {
            # If the HP.Firmware module PowerShell module is not found set HPCMSL to Unknown in order
            # to prevent attempting to flashing the BIOS since the module is required
            $File = Get-ChildItem $CMSL -Filter 'HP.Firmware.psd1' -Recurse
            if (!$File) {
                $TSvars.Add("HPCMSL", "Unknown")
                #Write-Output "Unable to detect HP CMSL. Setting HPCMSL to Unknown"
                #return
                }
            else {
                # Copy HP CMSL PowerShell module to PowerShell Module directory
                Write-Output "Copying $CMSL directory to $env:ProgramFiles\WindowsPowerShell\Modules"
                Copy-Item -Path "$CMSL\*" -Destination $env:ProgramFiles\WindowsPowerShell\Modules -Recurse -Force
                }
            try {$HPBiosVersion = get-hpbiosversion}
            catch {$HPBiosVersion = $null}
            if ($HPBiosVersion)
                {
                return $HPBiosVersion
                }
            else
                {
                $BIOS = Get-WmiObject -Class 'Win32_Bios'
                $CurrentBIOSVersion = $BIOS.SMBIOSBIOSVersion
                return $CurrentBIOSVersion
                }
           }
        }
    }

$BIOS = Get-WmiObject -Class 'Win32_Bios'
$CurrentBIOSDate = $BIOS.ReleaseDate

$Reporting_DownlevelBIOSVer = Get-HPBIOSVer -CMSL $CMSL
$Reporting_DownlevelBIOSVerRAW = $BIOS.SMBIOSBIOSVersion
$Reporting_DownlevelBIOSDate = $CurrentBIOSDate
$Reporting_StartFlashTime = Get-Date -f 's'


$TSENV.Value("Reporting_DownlevelBIOSVer") = $Reporting_DownlevelBIOSVer
$TSENV.Value("Reporting_DownlevelBIOSVerRAW") = $Reporting_DownlevelBIOSVerRAW
$TSENV.Value("Reporting_DownlevelBIOSDate") = $Reporting_DownlevelBIOSDate
$TSENV.Value('Reporting_StartFlashTime') = $Reporting_StartFlashTime

Write-Output "Reporting_DownlevelBIOSVer = $Reporting_DownlevelBIOSVer"
Write-Output "Reporting_DownlevelBIOSVer = $Reporting_DownlevelBIOSVerRAW"
Write-Output "Reporting_DownlevelBIOSDate = $Reporting_DownlevelBIOSDate"
Write-Output "Reporting_StartFlashTime = $Reporting_StartFlashTime"
