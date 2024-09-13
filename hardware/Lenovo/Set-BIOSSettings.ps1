<#Gary Blok
First draft of setting BIOS settings with PowerShell using all CIM stuff, none of this Get-WMIObject junk. ;-)
Testing on M60E | 11LV | M2SK Lenovo Desktop

Lenovo BIOS Settings return a really ugly dataset, so one of the first things this script does is build an Array of earier to use setting data.
This is still v1.0, I'll probably add more write-output and enabel transcription for the logging.  
I still need to add BIOS Password Tests, some of the plumbing is there, but not the checks... 

#>
$BIOSPass = 'P@ssw0rd'

#Connect to the Lenovo_BiosSetting WMI class
$SettingList = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosSetting).CurrentSetting | Where-Object {$_ -ne ""}
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


#Connect to the Lenovo_SetBiosSetting WMI class
$Interface = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosSetting

#Connect to the Lenovo_SaveBiosSettings WMI class
$SaveSettings = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SaveBiosSettings

#Connect to the Lenovo_BiosPasswordSettings WMI class
$PasswordSettings = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings

#Connect to the Lenovo_SetBiosPassword WMI class
$PasswordSet = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosPassword

#Test Setting
#$Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{ parameter = "WirelessLANPXE,Disabled,$BIOSPass,ascii,us" }



#List of settings to be configured ============================================================================================
#==============================================================================================================================
$Settings = (

    "AfterPowerLoss,Power On",
    "EnhancedPowerSavingMode,Disabled",
    "FastBoot,Enabled",
    "WakeonLAN,Automatic",
    "WakeUponAlarm,Daily Event"
)
#==============================================================================================================================
#==============================================================================================================================

foreach ($Setting in $Settings){
    $Setting = $Setting -split ","
    $SettingName = $Setting[0]
    $SettingValue = $Setting[1]

    if ($SettingName -in $SettingArray.name){
        $CurrentSettingValue = ($SettingArray | Where-Object {$_.Name -eq $SettingName}).CurrentValue
        Write-Host "Setting $SettingName | $SettingValue" -ForegroundColor Cyan
        if ($CurrentSettingValue -eq $SettingValue){
            Write-Host "Setting already Set Correctly: $SettingValue" -ForegroundColor Green
        }
        else {
            Write-Host "Updating Current Value of $CurrentSettingValue to $SettingValue" -ForegroundColor Yellow
            $Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{ parameter = "$SettingName,$SettingValue,$BIOSPass,ascii,us" }
        }
    }
    else {
        Write-Warning "Setting $SettingName not found in BIOS"
    }
}
