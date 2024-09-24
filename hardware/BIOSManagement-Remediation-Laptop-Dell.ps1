<#HP Laptop BIOS Setting Script to be used with Intune Remediations

This script should be target to HP Devices in Intune, but additional checks are in the script to ensure it doen't run on non-HP devices.


#>

$TranscriptPath = "C:\Windows\Temp\BIOSManagement-Remediation-Laptop.log"
Start-Transcript -Path $TranscriptPath -Append

#PreChecks for HP Laptops
$LatopChassisTypes = @("8","9","10","11","12","14","18","21","30","31")
$Baseboard = Get-CimInstance -ClassName Win32_Baseboard
$ChassisType = Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes 
if ($ChassisType -in $LatopChassisTypes){
    $IsLaptop = $true
}
else {
    $IsLaptop = $false
}
If ($Baseboard.Manufacturer -match "Dell") {
    $IsDell = $true
}


#If PreChecks are true, continue with script
if ($IsLaptop -and $IsDell) {
    Write-Output "PreChecks Passed, Continue with Script"
}
else {
    Write-Output "Not Applicable, exiting script"
    Stop-Transcript
    exit 0
}

#Password Portion
$BIOSPassword = 'P@ssw0rd' #Set your Password here - if using a TS, I recommend a hidden variable
$BIOSPasswordUTF = "<utf-16/>$BIOSPassword" #Must be set to UTF-16 for BIOS to read correctly

#Test for Password
$PasswordSet = (Get-CimInstance -Namespace root\hp/InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object {$_.Name -eq "Setup Password"}).IsSet

#Connect to WMI Interface
$Bios = Get-CimInstance -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSSettingInterface
$BiosSettings = Get-CimInstance  -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSEnumeration

#Setting Password & Doing Password Challenge
if ($PasswordSet -eq 1){
    $BIOSWD = $BIOSPasswordUTF
    #Test Password by getting and setting the Asset Information (setting it to the same value it was before)
    $CurrentAssetValue = Get-CimInstance  -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object {$_.Name -match "Asset Tracking"}
    $PasswordChallenge = $Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = "$($CurrentAssetValue.Name)"; Value = "$($CurrentAssetValue.Value)"; Password = "$BIOSPasswordUTF"}
    if ($PasswordChallenge.Return -eq 6){
        Write-Warning "The Password you provided is incorrect"
    }
    else{
        #Write-Output "Password Set Correctly"
    }
}
else {
    $BIOSWD = "<utf-16/>"
    #Write-Output "Using Blank Password"
}



#Desired BIOS Settings Table
#List of settings to be configured ============================================================================================
#==============================================================================================================================
$Global:Settings = (
    "Deep S3,Off",
    "Deep Sleep,Off",
    "S4/S5 Max Power Savings,Disable",
    "S5 Maximum Power Savings,Disable",
    "Num Lock State at Power-On,On",
    "NumLock on at boot,Enable",
    "Numlock state at boot,On",
    "PXE Internal IPV4 NIC boot,Enable",
    "PXE Internal NIC boot,Enable",
    "Wake On LAN,Boot to Hard Drive",
    "Swap Fn and Ctrl (Keys),Disable",
    "TPM State,Enable",
    "TPM Device,Available",
    "TPM Activation Policy,No prompts",
    "Lock BIOS Version, Disable",
    "Native OS Firmware Update Service,Enable",
    "Virtualization Technology (VTx),Enable",
    "Virtualization Technology for Directed I/O (VTd),Enable",
    "SVM CPU Virtualization,Enable",
    "Secure Boot,Enable",
    "UEFI Boot Options,Enable",
    "Configure Legacy Support and Secure Boot,Legacy Support Disable and Secure Boot Enable"
)
#==============================================================================================================================
#==============================================================================================================================

foreach ($Setting in $Settings){
    $Setting = $Setting -split ","
    $SettingName = $Setting[0]
    $SettingValue = $Setting[1]
    if ($SettingName -in $BiosSettings.Name){
        $CurrentSettingValue = ($BiosSettings | Where-Object {$_.Name -eq $SettingName}).CurrentValue
        Write-Output "Current Value: $currentSettingValue"
        Write-Output "Setting $SettingName | $SettingValue"
        #$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = "$SettingName"; Value = "$SettingValue"; Password = "$BIOSWD"}
    }
    else {
        Write-Warning "Setting $SettingName not found in BIOS"
    }
    #Write-Output $SettingName $SettingValue
    #$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = "$SettingName"; Value = "$SettingValue"; Password = "$BIOSWD"}
}

Stop-Transcript