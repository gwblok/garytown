<#  HP - Set WiFi Profiles into BIOS for use with Sure Recover - Baseline - ConfigMgr - Detection Script
    Gary Blok - HP - @gwblok
    Zach Unruh - HP

      
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
function Set-WiFiSetPersonalProfile([string]$SSID, [string]$Password){
    $bios = Get-WmiObject -Namespace root/HP/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $json = '{ "SSID": "' + $SSID + '", "Type": "Personal", "AutoConnect": "Enable", ' +
    '"ScanAnyway": "Enable", "Password": "' + $Password + '" } '
    $bios.SetBiosSetting("Preboot Wi-Fi Profile 1", $json, "")
}
function Get-WiFiBIOSProfiles {
    $bios = Get-CimInstance -Namespace root/hp/InstrumentedBIOS -ClassName HP_BIOSSetting
    $Profiles = $bios | Where-Object {$_.Name -like "Preboot Wi-Fi Profile*"}
    return $Profiles
}

#endregion Functions


#Get WiFi Settings from Online Windows OS

$SSID = Get-WiFiActiveProfileSSID
if ($SSID){ #THen there is an active WiFi and we successfully grabbed the SSID
    #Check if Current SSID already has Profile in BIOS for WiFi - IF YES - Exit - IF No, append.
    $Match = Get-WiFiBIOSProfiles | Where-Object {$_.Value -match $SSID}
    if ($Match){
        Write-Output "Compliant"
        #exit #Means that the active WiFi Profile in Windows is already added to BIOS
    }
    else { #Add Current Windows SSID & Password into BIOS into the first Free Available Profile spot.
        Write-Output "Non-Compliant"
    }
}
else {
    #No Active WiFi Profile, exit doing nothing.
    Write-Output "Compliant"
}

