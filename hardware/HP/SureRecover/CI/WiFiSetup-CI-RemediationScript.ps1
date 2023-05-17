<#  HP - Set WiFi Profiles into BIOS for use with Sure Recover - Baseline - ConfigMgr - Remediation Script
    Gary Blok - HP - @gwblok
    Zach Unruh - HP

    23.02.10
    Script Snips to configure HP Devices to allow Sure Recover to leverage WiFi on supported devices.
      - Disables FastBoot
      - Disables AMT
      - Adds Active WiFi information into BIOS for auto connect.
      
      - Full scripts & solution for CM Baseline / Intune Proactive Remediations coming in future... ping me if you're looking for them.
  
    Change Log
    23.02.11 - Fixed Logic for appending WiFi Profiles into BIOS
    23.02.11 - Added Function to get BIOS Settings to test AMT & Fast Boot state before blindly setting them.

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
function Set-WiFiSetPersonalProfile([string]$SSID, [string]$Password,[string]$ProfileNumber,[string]$Type){ #Type is Open or Personal
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $json = '{ "SSID": "' + $SSID + '", "Type": "' + $Type + '", "AutoConnect": "Enable", ' +
    '"ScanAnyway": "Enable", "Password": "' + $Password + '" } '
    $bios.SetBiosSetting("Preboot Wi-Fi Profile $ProfileNumber", $json, "")
    Write-Output "Set Preboot Wi-Fi Profile $ProfileNumber to $json"
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


<#
#Required BIOS Values... these will be set via Proactive Remediation / CM Baseline to ensure compliance with the desired setting results"

if ((Get-HPBIOSSettingWMI -SettingName "Intel Active Management Technology (AMT)").CurrentValue -ne "Disable"){
    Set-HPBIOSSettingWMI -Name "Intel Active Management Technology (AMT)" -Value "Disable"
}
if ((Get-HPBIOSSettingWMI -SettingName "Fast Boot").CurrentValue -ne "Disable"){
    Set-HPBIOSSettingWMI -Name "Fast Boot" -Value "Disable"
} 
#>




#Get WiFi Settings from Online Windows OS
if (Get-HPBIOSSettingWMI -SettingName "Preboot Wi-Fi Profile 1"){
    $SSID = Get-WiFiActiveProfileSSID
    if ($SSID){ #THen there is an active WiFi and we successfully grabbed the SSID
        $Password = Get-WiFiProfileKey -SSID $SSID
        if ($Password){[String]$Type = 'Personal'}
        else {[String]$Type = 'Open'}
        #Check if Current SSID already has Profile in BIOS for WiFi - IF YES - then recommit the Profile w/ password - IF No, append.
        $Match = Get-WiFiBIOSProfiles | Where-Object {$_.Value -match $SSID}
        if ($Match){
            $MatchNumber = $Match.Name.Replace("Preboot Wi-Fi Profile ",'')
            Set-WiFiSetPersonalProfile -SSID $SSID -Password $Password -ProfileNumber $MatchNumber -Type $Type
        }
        else { #Add Current Windows SSID & Password into BIOS into the first Free Available Profile spot.
            $FirstFree = Get-WiFiBIOSProfiles | Where-Object {$_.Value -match '"SSID":null'} | Select-Object -First 1
            if (!($FirstFree)){ #No more open profiles, wipe them all and start over
                Clear-WiFiBiosProfiles
                $FirstFree = Get-WiFiBIOSProfiles | Where-Object {$_.Value -match '"SSID":null'} | Select-Object -First 1    
            } 
            $ProfileNumber = $FirstFree.Name.Replace("Preboot Wi-Fi Profile ",'')
            Set-WiFiSetPersonalProfile -SSID $SSID -Password $Password -ProfileNumber $ProfileNumber -Type $Type
        }
    }
    else {
        #No Active WiFi Profile, exit doing nothing.
    }
}
else {
    #Device Not Configured for WiFi BIOS Profiles
}
