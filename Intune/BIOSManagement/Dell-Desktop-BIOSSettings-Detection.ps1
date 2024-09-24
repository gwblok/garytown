<#
Modified script to update BIOS for Dell Desktop Devices by Gary Blok


#ORIGINAL HEADER FROM SVEN: https://github.com/svenriebedell/Intune/tree/main/Remediation
_author_ = Sven Riebe <sven_riebe@Dell.com>
_twitter_ = @SvenRiebe
_version_ = 1.0.0
_Dev_Status_ = Test
Copyright ©2024 Dell Inc. or its subsidiaries. All Rights Reserved.

No implied support and test in test environment/device before using in any production environment.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Version Changes

    1.0.0    inital version
    24.09.24 - Gary Blok Mods 
    - Removed Function for Writing Events to Event Log
    - Added Function to detect Chassis
    - Added Function to detect Manufacturer
    - Add Transcription Log Location
    - Add PreChecks for Manufacturer and Chassis


.Synopsis
    This PowerShell is checking BIOS setting are compliant to IT requirements
    IMPORTANT: WMI BIOS is supported only on devices which developt after 2018, older devices does not supported by this powershell
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


function set-BIOSSetting {
        
    <#
        .Synopsis
        This function changing the Dell Client BIOS Settings by CIM

        .Description
        This function allows you agentless to set BIOS Pasword or to change BIOS Settings

        .Parameter SettingName
        Value is the name of the BIOS setting

        .Parameter SettingValue
        This is the value is the BIOS setting value, e.g. enabled or disabled or if you set/Change the new Password

        .Parameter BIOSPW
        This is the value is the existing BIOS Password set on the device. It will only needed if a BIOS Password is set on the device.


        Changelog:
            1.0.0 Initial Version
            1.0.1 add return for setting returncode to the mainscript


        .Example
        This example will set the Chassis Intrusion detection to SilentEnable, if the Device has no BIOS Admin Password.
        
        set-BIOSSetting -SettingName ChasIntrusion -SettingValue SilentEnable

        .Example
        This example will set the Chassis Intrusion detection to SilentEnable, if the Device has BIOS Admin Password.
        
        set-BIOSSetting -SettingName ChasIntrusion -SettingValue SilentEnable -BIOSPW <Your BIOS Admin PWD>

        .Example
        This example will set a new BIOS Admin Password for the first time
        
        set-BIOSSetting -SettingName Admin -SettingValue <Your BIOS Admin PWD>

        .Example
        This example will change BIOS Admin Password
        
        set-BIOSSetting -SettingName Admin -SettingValue <Your NEW BIOS Admin PWD> -BIOSPW <Your OLD BIOS Admin PWD>

        .Example
        This example will Clear BIOS Admin Password
        
        set-BIOSSetting -SettingName Admin -SettingValue ClearPWD -BIOSPW <Your OLD BIOS Admin PWD>

        #>
               
    param 
    (

        [Parameter(mandatory = $true)] [String]$SettingName,
        [Parameter(mandatory = $true)] [String]$SettingValue,
        [Parameter(mandatory = $false)] [String]$BIOSPW

    )


    #########################################################################################################
    ####                                    Program Section                                              ####
    #########################################################################################################

    # connect BIOS Interface
    try {
        # get BIOS WMI Interface
        $BIOSInterface = Get-CimInstance -Namespace root\dcim\sysman\biosattributes -Class BIOSAttributeInterface -ErrorAction Stop
        $SecurityInterface = Get-CimInstance -Namespace root\dcim\sysman\wmisecurity -Class SecurityInterface -ErrorAction Stop
        Write-Host "BIOS Interface connected" -ForegroundColor Green
    }
    catch {
        Write-Host "Error : BIOS interface access denied or unreachable" -ForegroundColor Red
        Write-Host "Status : false"
        Exit 1
    }


    # Check if BIOS Setting need BIOS Admin PWD
    try {
        # Check BIOS AttributName AdminPW is set
        $BIOSAdminPW = Get-CimInstance -Namespace root/dcim/sysman/wmisecurity -ClassName PasswordObject -Filter "NameId='Admin'" | Select-Object -ExpandProperty IsPasswordSet

        if ($BIOSAdminPW -match "1") {
            Write-Host "BIOS Admin PW is set on this Device"
                        
            If ($null -eq $BIOSPW) {
                Write-Host "Message : required parameter BIOSPW is empty"
                Return $false, "3"
                Exit 1
            }
                        
            #Get encoder for encoding password
            $encoder = New-Object System.Text.UTF8Encoding
                                        
            #encode the password
            $AdminBytes = $encoder.GetBytes($BIOSPW)

            If (($SettingName -ne "Admin") -and ($SettingName -ne "System")) {
                ######################################
                ####  BIOS Setting with Admin PWD ####
                ######################################
                                        
                try {
                    # Argument
                    $argumentsWithPWD = @{
                        AttributeName  = $SettingName; 
                        AttributeValue = $SettingValue; 
                        SecType        = 1; 
                        SecHndCount    = $AdminBytes.Length; 
                        SecHandle      = $AdminBytes;
                    }
                                                
                    # Set a BIOS Attribute
                    Write-Host "Set Bios"
                    $SetResult = Invoke-CimMethod -InputObject $BIOSInterface -MethodName SetAttribute -Arguments $argumentsWithPWD -ErrorAction Stop
                                                
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS setting $result"
                        return $false, $SetResult.Status
                    }
                }
                catch {
                    $errMsg = $_.Exception.Message
                    write-host $errMsg
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS Password setting $result"
                        return $false, $SetResult.Status
                        exit 1
                    }
                }
            }
            else {
                ################################################
                ####  BIOS Change/Delete Admin or Sytem PWD ####
                ################################################
                try {
                    If ($SettingValue -eq "ClearPWD") {
                        Write-Host "Admin PWD clear"
                        # Argument
                        $argumentsWithPWD = @{
                            NameId      = $SettingName;
                            NewPassword = "";
                            OldPassword = $BIOSPW;
                            SecType     = 1;
                            SecHndCount = $AdminBytes.Length;
                            SecHandle   = $AdminBytes;
                        }
                    }
                    else {
                        Write-Host "Admin PWD change"
                        # Argument
                        $argumentsWithPWD = @{
                            NameId      = $SettingName;
                            NewPassword = $SettingValue;
                            OldPassword = $BIOSPW;
                            SecType     = 1;
                            SecHndCount = $AdminBytes.Length;
                            SecHandle   = $AdminBytes;
                        }
                    }
 
                    
                    # Set a BIOS Attribute
                    $SetResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetnewPassword -Arguments $argumentsWithPWD #-ErrorAction Stop
                                        
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS Password setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS Password setting $result"
                        return $false, $SetResult.Status
                    }
                }
                catch {
                    $errMsg = $_.Exception.Message
                    write-host $errMsg
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS Password setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS Password setting $result"
                        return $false, $SetResult.Status
                        exit 1
                    }
                }                                      
            }
        }
        Else {
            Write-Host "No BIOS Admin PW is set on this Device"

            If (($SettingName -ne "Admin") -and ($SettingName -ne "System")) {
                #########################################
                ####  BIOS Setting without Admin PWD ####
                #########################################
                try {
                    # Argument
                    $argumentsNoPWD = @{ 
                        AttributeName  = $SettingName; 
                        AttributeValue = $SettingValue;
                        SecType        = 0;
                        SecHndCount    = 0;
                        SecHandle      = @()
                    }  
                                        
                    Write-Host "Set Bios Settings"
                    # Set a BIOS Attribute ChasIntrusion to EnabledSilent (BIOS password is not set)
                    $SetResult = Invoke-CimMethod -InputObject $BIOSInterface -MethodName SetAttribute -Arguments $argumentsNoPWD -ErrorAction Stop
        
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS setting $result"
                        return $false, $SetResult.Status
                    }
                }
                catch {
                    $errMsg = $_.Exception.Message
                    write-host $errMsg
                    Write-Host "Message : BIOS setting failed"
                    return $false, $SetResult.Status
                    exit 1
                }


            }
            else {
                ######################################
                ####  BIOS Set Admin or Sytem PWD ####
                ######################################
                try {
                                        
                    # Argument
                    $argumentsNoPWD = @{
                        NameId      = $SettingName;
                        NewPassword = $SettingValue;
                        OldPassword = "";
                        SecType     = 0;
                        SecHndCount = 0;
                        SecHandle   = @();
                    }
                                        
                    Write-Host "Set Password"
                                        
                    # Set a BIOS Passwords
                    $SetResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetnewPassword -Arguments $argumentsNoPWD -ErrorAction Stop
        
                    If ($SetResult.Status -eq 0) {
                        Write-Host "Message : BIOS Password setting success"
                        return $true
                    }
                    else {
                        switch ( $SetResult.Status ) {
                            0 { $result = 'Success' }
                            1 { $result = 'Failed' }
                            2 { $result = 'Invalid Parameter' }
                            3 { $result = 'Access Denied' }
                            4 { $result = 'Not Supported' }
                            5 { $result = 'Memory Error' }
                            6 { $result = 'Protocol Error' }
                            default { $result = 'Unknown' }
                        }
                        Write-Host "Message : BIOS setting $result"
                        return $false, $SetResult.Status
                    }
                }
                catch {
                    $errMsg = $_.Exception.Message
                    write-host $errMsg
                    Write-Host "Message : BIOS setting failed"
                    return $false, $SetResult.Status
                    exit 1
                }
            }
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        write-host $errMsg
        If ($SetResult.Status -eq 0) {
            Write-Host "Message : BIOS setting success"
            return $true
        }
        else {
            switch ( $SetResult.Status ) {
                0 { $result = 'Success' }
                1 { $result = 'Failed' }
                2 { $result = 'Invalid Parameter' }
                3 { $result = 'Access Denied' }
                4 { $result = 'Not Supported' }
                5 { $result = 'Memory Error' }
                6 { $result = 'Protocol Error' }
                default { $result = 'Unknown' }
            }
            Write-Host "Message : BIOS Password setting $result"
            return $false, $SetResult.Status
        }
        write-host "Status : False"
        exit 1
    }
}
#endregion

#########################################################################################################
####                                    Varible Section                                              ####
#########################################################################################################


$Compliance = $True
$TranscriptPath = "$env:SystemDrive\Windows\Temp\BIOSManagement-Remediation.log"
$BIOSCompliant = @(
    [PSCustomObject]@{BIOSSettingName = "AutoOn"; BIOSSettingValue = "Everyday"; WMIClass = "EnumerationAttribute" }
    [PSCustomObject]@{BIOSSettingName = "Fastboot"; BIOSSettingValue = "Minimal"; WMIClass = "EnumerationAttribute" }
    [PSCustomObject]@{BIOSSettingName = "WakeOnLan"; BIOSSettingValue = "LanOnly"; WMIClass = "EnumerationAttribute" }  
    [PSCustomObject]@{BIOSSettingName = "NumLockLed"; BIOSSettingValue = "Enabled"; WMIClass = "EnumerationAttribute" }  
)

$Manufacturer = Get-Manufacturer
$ChassisType = Get-ChassisType
$IntendedManufacturer = "Dell"
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

# get BIOS setting from device
try {
    [array]$BIOSCompliantStatus = @()
        
    foreach ($Setting in $BIOSCompliant) {
        # Temp Array
        $TempBIOSStatus = New-Object -TypeName psobject
                
        $TempBIOSStatus = Get-CimInstance -Namespace root/dcim/sysman/biosattributes -ClassName $Setting.WMIClass -ErrorAction Stop | Where-Object { $_.AttributeName -eq $Setting.BIOSSettingName } -ErrorAction Stop | Select-Object AttributeName, CurrentValue
            
        [array]$BIOSCompliantStatus += $TempBIOSStatus
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "Get BIOS settings failed"
    Stop-Transcript
    Exit 1
}
# check setting compliants
[array]$SettingCompliant = @()

foreach ($Status in $BIOSCompliantStatus) {
        
    $TempSettingCompliant = New-Object -TypeName psobject

    ForEach ($Compliant in $BIOSCompliant) {
        If ($Compliant.BIOSSettingName -eq $Status.AttributeName) {
                        

            If ($Compliant.BIOSSettingValue -eq $Status.CurrentValue) {
                $TempSettingCompliant | Add-Member -MemberType NoteProperty -Name AttributeName -Value $Status.AttributeName
                $TempSettingCompliant | Add-Member -MemberType NoteProperty -Name Compliant -Value $true

            }
            else {
                $TempSettingCompliant | Add-Member -MemberType NoteProperty -Name AttributeName -Value $Status.AttributeName
                $TempSettingCompliant | Add-Member -MemberType NoteProperty -Name Compliant -Value $false
            }
        }    	
    }
    $SettingCompliant += $TempSettingCompliant
}



# if one or more settings not compliant Exit 1 other otherwise Exit 0

foreach ($Compliant in $SettingCompliant) {
    if ($Compliant.Compliant -eq $true) {
        Write-Host $Compliant.AttributeName "is compliant" -ForegroundColor Green
    }
    else {   
        $Compliance = $False
        Write-Host $Compliant.AttributeName "is NOT compliant" -ForegroundColor Red

    }
}
if ($Compliance -eq $False) {
    Write-Host "BIOS settings are not compliant" -ForegroundColor Red
    Stop-Transcript
    Exit 1
}
else {
    Write-Host "BIOS settings are compliant" -ForegroundColor Green
    Stop-Transcript
    Exit 0
}
#########################################################################################################
####                                    END                                                          ####
#########################################################################################################