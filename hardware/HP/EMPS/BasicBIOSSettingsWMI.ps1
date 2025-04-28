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


#Start Updating Settings
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Fast Boot';                                         Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Deep S3';                                           Value = "Off";                                           Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Deep Sleep';                                        Value = "Off";                                           Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'S4/S5 Max Power Savings';                           Value = "Disable";                                       Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Num Lock State at Power-On';                        Value = "On";                                            Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'NumLock on at boot';                                Value = "Disable";                                       Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Numlock state at boot';                             Value = "On";                                            Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'PXE Internal IPV4 NIC boot';                        Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'PXE Internal NIC boot';                             Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Wake On LAN';                                       Value = "Boot to Hard Drive";                            Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'TPM State';                                         Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'TPM Device';                                        Value = "Available";                                     Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'TPM Activation Policy';                             Value = "No prompts";                                    Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Lock BIOS Version';                                 Value = "Disable";                                       Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Native OS Firmware Update Service';                 Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Virtualization Technology (VTx)';                   Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Virtualization Technology for Directed I/O (VTd)';  Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'SVM CPU Virtualization';                            Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Secure Boot';                                       Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'UEFI Boot Options';                                 Value = "Enable";                                        Password = "$BIOSWD"}
$Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = 'Configure Legacy Support and Secure Boot';          Value = "Legacy Support Disable and Secure Boot Enable"; Password = "$BIOSWD"}
