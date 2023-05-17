<#  HP - Set WiFi Profiles into BIOS for use with Sure Recover - Proactive Remediations via Intune
    Gary Blok - HP - @gwblok

    23.03.01 - Intune Proactive Detection Script

#>

#region Functions
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
Function Get-WiFiProfileKey {
    param (
    [String]$SSID
    )
    $ProfileInfo = netsh wlan show profile name=$SSID key=clear
    $Key = ($ProfileInfo | Select-String "Key Content").ToString().Split(":")  | Select-Object -Last 1
    $Key = $Key.Trim()
    return $Key
}
function Set-WiFiSetPersonalProfile([string]$SSID, [string]$Password,[string]$ProfileNumber){
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $json = '{ "SSID": "' + $SSID + '", "Type": "Personal", "AutoConnect": "Enable", ' +
    '"ScanAnyway": "Enable", "Password": "' + $Password + '" } '
    $bios.SetBiosSetting("Preboot Wi-Fi Profile $ProfileNumber", $json, "")
}
function Set-HPBIOSSettingWMI([string]$SettingName, [string]$Value){
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $BIOS.SetBIOSSetting($SettingName,$Value)
}
function Get-WiFiBIOSProfiles {
    $bios = Get-CimInstance -Namespace root/hp/InstrumentedBIOS -ClassName HP_BIOSSetting
    $Profiles = $bios | Where-Object {$_.Name -like "Preboot Wi-Fi Profile*"}
    return $Profiles
}
function Get-HPBIOSSettingWMI([string]$SettingName) {
    $bios = Get-CimInstance -Namespace root/hp/InstrumentedBIOS -ClassName HP_BIOSSetting
    $Setting = $bios | Where-Object {$_.Name -eq $SettingName}
    return $Setting
}
function Clear-WiFiBIOSProfiles{  #Not being used, but keeping for Reference.
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface   
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 1", "", "")
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 2", "", "")
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 3", "", "")
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 4", "", "")
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 5", "", "")
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 6", "", "")
}

#endregion Functions


#Below will be another Proactive Remediation / CM Baseline that will run randomly to add the User's Active WiFi profile to BIOS

#Detect if Script is applicable
$Baseboard = Get-CimInstance -ClassName Win32_Baseboard
If (!($Baseboard.Manufacturer -match "HP") -or ($Baseboard.Manufacturer -match "Hewlett")) {
    exit 0 # Not HP Device
}
if (!(Get-HPBIOSSettingWMI -SettingName "Preboot Wi-Fi Profile 1")){
    exit 0 # Isn't configured for WiFi Profiles in BIOS - Device might not support PreBoot WiFi, or is not configured properly yet (Might still need to disable AMT)
}
if (!(Get-WiFiActiveProfileSSID)){
    exit 0 # Has no Active WiFi Profile in Windows when this script runs.
}
else{
    exit 1 # Has Active Profile - Exit 1 to remediation script.
}
