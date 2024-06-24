#Password Portion
$BIOSPassword = 'P@ssw0rd' #Set your Password here - if using a TS, I recommend a hidden variable

#Connect to WMI Interface
$Bios = Get-CimInstance -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSSettingInterface
$BiosSettings = Get-CimInstance  -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSEnumeration

#Setting Password & Doing Password Challenge
if (Get-HPBIOSSetupPasswordIsSet){
    $BIOSWD = $BIOSPassword
    #Test Password by getting and setting the Asset Information (setting it to the same value it was before)
    $CurrentAssetValue = Get-HPBIOSSettingsList | Where-Object {$_.Name -match "Asset Tracking"}
    try {
        Write-Host "Testing Password by Setting Asset Value to Current Value already set" -ForegroundColor Cyan
        Set-HPBIOSSettingValue -Name $CurrentAssetValue.Name -Value $CurrentAssetValue.Value -Password "$BIOSPassword"
    }
    catch{ Write-Warning "The Password you provided is incorrect" }
}
else {
    $BIOSWD = ""
    #Write-Output "Using Blank Password"
}

try {Set-HPBIOSSettingValue -Name 'Fast Boot'                                         -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Deep S3'                                           -Value "Off"                                           -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Deep Sleep'                                        -Value "Off"                                           -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'S4/S5 Max Power Savings'                           -Value "Disable"                                       -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Num Lock State at Power-On'                        -Value "On"                                            -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'NumLock on at boot'                                -Value "Disable"                                       -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Numlock state at boot'                             -Value "On"                                            -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'PXE Internal IPV4 NIC boot'                        -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'PXE Internal NIC boot'                             -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Wake On LAN'                                       -Value "Boot to Hard Drive"                            -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'TPM State'                                         -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'TPM Device'                                        -Value "Available"                                     -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'TPM Activation Policy'                             -Value "No prompts"                                    -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Lock BIOS Version'                                 -Value "Disable"                                       -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Native OS Firmware Update Service'                 -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Virtualization Technology (VTx)'                   -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Virtualization Technology for Directed I/O (VTd)'  -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'SVM CPU Virtualization'                            -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Secure Boot'                                       -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'UEFI Boot Options'                                 -Value "Enable"                                        -Password "$BIOSWD"} catch {}
try {Set-HPBIOSSettingValue -Name 'Configure Legacy Support and Secure Boot'          -Value "Legacy Support Disable and Secure Boot Enable" -Password "$BIOSWD"} catch {}
