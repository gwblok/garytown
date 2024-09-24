<#
Script to update BIOS Settings for Lenovo Desktop Devices by Gary Blok

<#Version Changes

    24.09.24 - Gary Blok Initial Version

#>

<#
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


#Connect to WMI Interface

#Connect to the Lenovo_SetBiosSetting WMI class
$Interface = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosSetting

#Connect to the Lenovo_SaveBiosSettings WMI class
$SaveSettings = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SaveBiosSettings

#Connect to the Lenovo_BiosPasswordSettings WMI class
$PasswordSettings = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings

#Connect to the Lenovo_SetBiosPassword WMI class
$PasswordSet = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosPassword


witch($PasswordSettings.PasswordState)
{
	{$_ -eq 0}
	{
		Write-Output "No passwords are currently set"
	}
	{($_ -eq 2) -or ($_ -eq 3) -or ($_ -eq 6) -or ($_ -eq 7) -or ($_ -eq 66) -or ($_ -eq 67) -or ($_ -eq 70) -or ($_-eq 71)}
	{
		$SvpSet = $true
		Write-Output "The supervisor password is set"
	}
	{($_ -eq 64) -or ($_ -eq 65) -or ($_ -eq 66) -or ($_ -eq 67) -or ($_ -eq 68) -or ($_ -eq 69) -or ($_ -eq 70) -or ($_-eq 71)}
	{
		$SmpSet = $true
		Write-Output  "The system management password is set"
	}
	default
	{
	}
}



#Connect to the Lenovo_BiosSetting WMI class
$SettingList = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosSetting).CurrentSetting | Where-Object {$_ -ne ""}

#Cleanup Setting Data and build array
$SettingArray = @()

Foreach ($Setting in $SettingList){
    $Name = $Setting.Split(",")[0]
    $CurrentValue = ($Setting.Split(";")[0]).split(",") | Select-Object -Last 1
    $OptionalValues = ($Setting.Split(";") | Select-Object -Last 1).replace("[","").replace("]","")
    $SettingObject = New-Object PSObject -Property @{
        Name = $Name
        CurrentValue = $CurrentValue 
        OptionalValues = $OptionalValues
    }
    $SettingArray += $SettingObject

}

# get BIOS setting from device
try {
    [array]$BIOSCompliantStatus = @()
        
    foreach ($Setting in $BIOSCompliant) {
        # Temp Array
        $TempBIOSStatus = New-Object -TypeName psobject
                
        $TempBIOSStatus = $SettingArray | Where-Object { $_.Name -eq $Setting.BIOSSettingName } -ErrorAction Stop | Select-Object Name, CurrentValue
            
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
                if ($SvpSet){
                    $Result = $Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{ parameter = "$SettingName,$SettingValue,$BIOSPass,ascii,us" }
                }
                else {
                    $Result = $Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{ parameter = "$SettingName,$SettingValue" }
                }
                
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
if ($SaveRequired -and $SvpSet){
    $Results = $SaveSettings  | Invoke-CimMethod -MethodName SaveBiosSettings -Arguments @{ parameter = "$BIOSPass,ascii,us" }
}


Write-Host "Remediation script successful"
Stop-Transcript
Exit 0


#########################################################################################################
####                                    END                                                          ####
#########################################################################################################