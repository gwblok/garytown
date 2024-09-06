<#Requires the PS Provider already installed.

Tested with Dell PS Provder 2.8.0 on Dell Latitude E5750

#>

$Settings = @(
#TPM
@{Name = "TpmActivation"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
@{Name = "TpmPpiAcpi"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
@{Name = "TpmPpiClearOverride"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
@{Name = "TpmPpiDpo"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
@{Name = "TpmPpiPo"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
@{Name = "TpmSecurity"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\TPMSecurity"}
#ThunderBolt
@{Name = "ThunderboltBoot"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\USBConfiguration"}
@{Name = "ThunderboltPorts"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\USBConfiguration"}
@{Name = "ThunderboltPreboot"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\USBConfiguration"}
@{Name = "ThunderboltSecLvl"; DesiredValue = "NoSec" ; Location =	"DellSmbios:\USBConfiguration"}
@{Name = "AlwaysAllowDellDocks"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\USBConfiguration"}

#Power
@{Name = "WakeOnLan"; DesiredValue = "LanOnly" ; Location =	"DellSmbios:\PowerManagement"}
@{Name = "WakeOnAc"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\PowerManagement"}
@{Name = "PrimaryBattChargeCfg"; DesiredValue = "PrimAcUse" ; Location =	"DellSmbios:\PowerManagement"}

#Other
@{Name = "Virtualization"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\VirtualizationSupport"}

@{Name = "UefiNwStack"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\SystemConfiguration"}
@{Name = "EmbNic1"; DesiredValue = "EnabledPxe" ; Location =	"DellSmbios:\SystemConfiguration"}

@{Name = "LegacyOrom"; DesiredValue = "Disabled" ; Location =	"DellSmbios:\AdvancedBootOptions"}
@{Name = "AttemptLegacyBoot"; DesiredValue = "Disabled" ; Location =	"DellSmbios:\AdvancedBootOptions"}

@{Name = "CapsuleFirmwareUpdate"; DesiredValue = "Enabled" ; Location =	"DellSmbios:\Security"}
)





#Import Module to Enable Provider
if (!(get-module -name DellBIOSProvider)){
    Import-Module -Name  DellBIOSProvider -Force
}
#Set Location to Dell SMBIOS Provider:
if ((Get-Location) -ne "DellSmbios:\"){
    Set-Location -Path DellSmbios:\
}

$PasswordValue = 'P@ssw0rd'

foreach ($Setting in $Settings){
    Write-Output "Starting $($Setting.Name)"
    $CurrentValue = (Get-Item -Path "$($Setting.Location)\$($Setting.Name)").CurrentValue
    if ($CurrentValue -ne $Setting.DesiredValue){
        Write-Output "Updating $($Setting.Name) to $($Setting.DesiredValue)"
        Set-Item -Path "$($Setting.Location)\$($Setting.Name)" -Value $Setting.DesiredValue -PassThru -Password $PasswordValue
    }
    else {
        Write-Output "$($Setting.Name) already set Correctly, ($($Setting.DesiredValue)), No change needed"
    }
}
