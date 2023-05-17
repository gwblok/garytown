<#  HP - Set BIOS Settings for use with PreBoot WiFi - Proactive Remediations via Intune
    Remediation Script
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

function Set-HPBIOSSettingWMI([string]$SettingName, [string]$Value, [string]$BIOSPassword){
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $BIOSSetting = gwmi -class hp_biossetting -Namespace "root\hp\instrumentedbios"
    If (($BIOSSetting | ?{ $_.Name -eq 'Setup Password' }).IsSet -eq 0)
    {
        $Result = $BIOS.SetBIOSSetting($SettingName,$Value)
    }
    elseif (($BIOSSetting | ?{ $_.Name -eq 'Setup Password' }).IsSet -eq 1)
    {
        $PW = "<utf-16/>$BIOSPW"
        $Result = $BIOS.SetBIOSSetting($SettingName,$Value,$PW)
    }
   
}


foreach ($Setting in $BIOSSettingTable_WiFi){
    $BIOSSetting = $Setting.Setting
    $DesiredValue = $Setting.Value
    $BIOSInfo = Get-HPBIOSSettingWMI -SettingName $BIOSSetting
    if ($BIOSInfo){
        if ($BIOSInfo.CurrentValue -ne $DesiredValue){
            Write-Output "$BIOSSetting | Current Value: $($BIOSInfo.CurrentValue)"
            Write-Output "  Setting to $DesiredValue"
            Set-HPBIOSSettingWMI -SettingName $BIOSSetting -Value $DesiredValue   
        }
    }
}

