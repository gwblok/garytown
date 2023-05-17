<#  HP - Set BIOS Settings for use with PreBoot WiFi - Proactive Remediations via Intune
    Detection Script
    Gary Blok - HP - @gwblok

#>

$BIOSSettingTable_WiFi = @(
@{ Setting = 'Preboot Wi-Fi Master Auto Connect'; Value = 'Enable'}
@{ Setting = 'Fast Boot'; Value = 'Disable'}
@{ Setting = 'Intel Active Management Technology (AMT)'; Value = 'Disable'}
)

function Get-HPBIOSSettingWMI([string]$SettingName) {
    $bios = Get-CimInstance -Namespace root/hp/InstrumentedBIOS -ClassName HP_BIOSSetting
    $Setting = $bios | Where-Object {$_.Name -eq $SettingName}
    return $Setting
}


foreach ($Setting in $BIOSSettingTable_WiFi){
    $BIOSSetting = $Setting.Setting
    $DesiredValue = $Setting.Value
    $BIOSInfo = Get-HPBIOSSettingWMI -SettingName $BIOSSetting
    if ($BIOSInfo){
        if ($BIOSInfo.CurrentValue -ne $DesiredValue){
            exit 1 #Exit 1 to Start Remediation
        }
    }
}
