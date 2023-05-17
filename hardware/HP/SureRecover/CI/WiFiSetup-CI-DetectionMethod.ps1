<#  HP - Set WiFi Profiles into BIOS for use with Sure Recover - Baseline - ConfigMgr - CI Detection Methods
    Gary Blok - HP - @gwblok

This script is used as the CI's detection to determine if it should even run the CI or not on a system (Not the Detection script under Settings)

This will only allow the CI to run on the computer if:
    1) Device is HP
    2) Device is configured to store WiFi Info in BIOS
    3) Has an active WiFi Profile


#>


function Get-HPBIOSSettingWMI([string]$SettingName) {
    $bios = Get-CimInstance -Namespace root/hp/InstrumentedBIOS -ClassName HP_BIOSSetting
    $Setting = $bios | Where-Object {$_.Name -eq $SettingName}
    return $Setting
}
Function Get-WiFiActiveProfileSSID {
    $Interfaces = netsh wlan show interfaces
    try {
        $ActiveProfile = ($Interfaces | Select-String "Profile"| Where-Object {$_ -notmatch "Connection"}).ToString().Split(":") | Select-Object -Last 1 -ErrorAction SilentlyContinue
        }
    catch{}
    if ($ActiveProfile){
        $ActiveProfile = $ActiveProfile.Trim()
        return $ActiveProfile
    }
}

$Baseboard = Get-CimInstance -ClassName Win32_Baseboard
#Confirm Device is HP
If (($Baseboard.Manufacturer -match "HP") -or ($Baseboard.Manufacturer -match "Hewlett")) {
    #Confirm Device is capable of storing WiFi in BIOS
    if (Get-HPBIOSSettingWMI -SettingName "Preboot Wi-Fi Profile 1"){
        #Check for an Active WiFi Connection
        Get-WiFiActiveProfileSSID
    }
}
