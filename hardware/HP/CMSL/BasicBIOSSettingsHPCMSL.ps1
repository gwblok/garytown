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

Set-HPBIOSSettingValue -Name 'Fast Boot' -Value 'Enable' -Password $BIOSWD
