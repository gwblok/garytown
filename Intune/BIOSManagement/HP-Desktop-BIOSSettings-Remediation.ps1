<#
Script to update BIOS Settings for HP Desktop Devices by Gary Blok

Version Changes

    24.09.24 - Gary Blok Initial Version


.Synopsis
    This PowerShell is checking BIOS setting are compliant to IT requirements
    IMPORTANT: This script does not reboot the system to apply or query system.
.DESCRIPTION
    Powershell using WMI and read the existing BIOS settings and compare with IT required
#>

#Variables


#region Functions
#########################################################################################################
####                                    Function Section                                             ####
#########################################################################################################




Function Get-ChassisType {
    <#
    .SYNOPSIS
    This function returns the Chassis Type of the device
    .DESCRIPTION
    This function returns the Chassis Type of the device
    .EXAMPLE
    Get-ChassisType
    #>
    $DesktopChassisTypes = @("3", "4", "5", "6", "7", "13", "15", "16", "35")
    $LatopChassisTypes = @("8", "9", "10", "11", "12", "14", "18", "21", "30", "31")
    $ChassisType = Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes 
    if ($ChassisType -in $LatopChassisTypes) {
        return "Laptop"
    }
    elseif ($ChassisType -in $DesktopChassisTypes) {
        return "Desktop"
    }
    else {
        return $ChassisType 
    }
}

Function Get-Manufacturer {
    <#
    .SYNOPSIS
    This function returns the Manufacturer of the device
    .DESCRIPTION
    This function returns the Manufacturer of the device
    .EXAMPLE
    Get-Manufacturer
    #>
    $Baseboard = Get-CimInstance -ClassName Win32_Baseboard
    If ($Baseboard.Manufacturer -match "Dell") {
        return "Dell"
    }
    ElseIf ($Baseboard.Manufacturer -match "HP" -or $Baseboard.Manufacturer -match "Hewlett") {
        return "HP"
    }
    else {
        return $Baseboard.Manufacturer 
    }
}


#endregion

#########################################################################################################
####                                    Varible Section                                              ####
#########################################################################################################

#Password Portion
$BIOSPassword = 'P@ssw0rd' #Set your Password here - if using a TS, I recommend a hidden variable
$BIOSPasswordUTF = "<utf-16/>$BIOSPassword" #Must be set to UTF-16 for BIOS to read correctly



$TranscriptPath = "$env:SystemDrive\Windows\Temp\BIOSManagement-Remediation.log"
$BIOSCompliant = @(
    [PSCustomObject]@{BIOSSettingName = "Fast Boot"; BIOSSettingValue = "Enable" }
    [PSCustomObject]@{BIOSSettingName = "Startup Delay (sec.)"; BIOSSettingValue = "0" }
    [PSCustomObject]@{BIOSSettingName = "S5 Maximum Power Savings"; BIOSSettingValue = "Disable" }  
    [PSCustomObject]@{BIOSSettingName = "After Power Loss"; BIOSSettingValue = "Power On" }
    [PSCustomObject]@{BIOSSettingName = "Wake On LAN"; BIOSSettingValue = "Boot to Hard Drive" }
    [PSCustomObject]@{BIOSSettingName = "NumLock on at boot"; BIOSSettingValue = "Enable" }  
)

$Manufacturer = Get-Manufacturer
$ChassisType = Get-ChassisType
$IntendedManufacturer = "HP"
$IntendedChassisType = "Desktop"

#########################################################################################################
####                                    Program Section                                              ####
#########################################################################################################


Start-Transcript -Path $TranscriptPath -Append
Write-Output "Starting BIOS Remediation Script on $Manufacturer $ChassisType Device"
Write-Output "Intended Manufacturer: $IntendedManufacturer & Intended Chassis Type: $IntendedChassisType"

#PreChecks
If ($Manufacturer -notmatch $IntendedManufacturer) {
    Write-Output "Manufacturer is not $IntendedManufacturer, exiting script"
    Stop-Transcript
    Exit 0
}
if ($ChassisType -ne $IntendedChassisType) {
    Write-Output "Chassis Type is not $IntendedChassisType, exiting script"
    Stop-Transcript
    Exit 0
}

#Test for Password
$PasswordSet = (Get-CimInstance -Namespace root\hp/InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object {$_.Name -eq "Setup Password"}).IsSet

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

#Connect to WMI Interface
$Bios = Get-CimInstance -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSSettingInterface
$BiosSettings = Get-CimInstance  -Namespace root/HP/InstrumentedBIOS -ClassName HP_BIOSEnumeration

# get BIOS setting from device
try {
    [array]$BIOSCompliantStatus = @()
        
    foreach ($Setting in $BIOSCompliant) {
        # Temp Array
        $TempBIOSStatus = New-Object -TypeName psobject
                
        $TempBIOSStatus = $BiosSettings | Where-Object { $_.Name -eq $Setting.BIOSSettingName } -ErrorAction Stop | Select-Object Name, CurrentValue
            
        [array]$BIOSCompliantStatus += $TempBIOSStatus
    }
}
catch {
    Write-Host "Get BIOS settings failed"
    Stop-Transcript
    Exit 1
}

foreach ($Status in $BIOSCompliantStatus) {
        
    ForEach ($Compliant in $BIOSCompliant) {
        If ($Compliant.BIOSSettingName -eq $Status.Name) {                 
            If ($Compliant.BIOSSettingValue -eq $Status.CurrentValue) {
                Write-Host $Status.Name "setting not changed"
            }
            else {
                $Result = $Bios | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Name = "$($Status.Name)"; Value = "$($Compliant.BIOSSettingValue)"; Password = "$BIOSWD"}
                If ($result.ReturnValue -eq $true) {
                    Write-Host $Status.Name "setting is changed"
                }
                else {
                    Write-Host "BIOS setting failed wrong parameter or wrong BIOS Password" -ForegroundColor Red
                    Stop-Transcript
                    Exit 1
                }
            }
        }    	
    }
}


Write-Host "Remediation script successful"
Stop-Transcript
Exit 0


#########################################################################################################
####                                    END                                                          ####
#########################################################################################################