<#  Addon Enhancement for HP Devices using MSEndpointMgr's Enhanced Inventory
https://msendpointmgr.com/2022/01/17/securing-intune-enhanced-inventory-with-azure-function/

Call this script from theirs to add additional inventory into Log Analytics for HP devices.

.ChangeLog
      23.09.07.01 - First Release as Addon for HP Devices
#>

$CollectHPBIOSSettingInventory = $true #Sub selection of BIOS Settings I've picked... let me know if you want more.
$CollectHPBIOSStringInventory = $false #This is a lot of extra stuff, look at the info and decide if you want it.
$CollectHPDockInventory = $true #HP Dock Inventory

<#
Others to add:

Sure Recover
Secure Platform

#>

$HPBIOSSettingLogName = "HPBIOSSettingInventory"
$HPBIOSStringLogName = "HPBIOSStringInventory"
$HPDockLogName = "HPDockInventory"


#region HPBIOSINVENTORY
if ($CollectHPBIOSSettingInventory) {
	
	#Get BIOS Info from WMI
    $namespace = "ROOT\HP\InstrumentedBIOS"
    $classname = "HP_BIOSSetting"	
    
    $BIOSSetting = Get-CimInstance -Namespace $namespace -ClassName $classname


    if (($BIOSSetting | ?{ $_.Name -eq 'Setup Password' }).IsSet -eq 1){$PasswordSet = $true}
    else {$PasswordSet = $false}
    $ProductName = ($BIOSSetting | Where-Object {$_.Name -match "Product Name"}).Value
    $SerialNumber = ($BIOSSetting | Where-Object {$_.Name -match "Serial Number"}).Value
    $BornOnDate = ($BIOSSetting | Where-Object {$_.Name -match "Born On Date"}).Value
    $WakeOnLAN = ($BIOSSetting | Where-Object {$_.Name -eq "Wake on LAN"}).CurrentValue
    $VTX = ($BIOSSetting | Where-Object {$_.Name -eq "Virtualization Technology (VTx)"}).CurrentValue
    $VTd = ($BIOSSetting | Where-Object {$_.Name -eq "Virtualization Technology for Directed I/O (VTd)"}).CurrentValue
    $PPI = ($BIOSSetting | Where-Object {$_.Name -eq "Physical Presence Interface"}).CurrentValue
    $TPMActivationPolicy = ($BIOSSetting | Where-Object {$_.Name -eq "TPM Activation Policy"}).CurrentValue
    $LockBIOSVersion = ($BIOSSetting | Where-Object {$_.Name -eq "Lock BIOS Version"}).CurrentValue
    $AutomaticBIOSUpdate = ($BIOSSetting | Where-Object {$_.Name -eq "Automatic BIOS Update Setting"}).CurrentValue
    $NativeOSFirmwareUpdateService = ($BIOSSetting | Where-Object {$_.Name -eq "Native OS Firmware Update Service"}).CurrentValue
    $BatterySafetyMode = ($BIOSSetting | Where-Object {$_.Name -eq "Battery Safety Mode"}).CurrentValue
    $PrimaryBatterySerialNumber = ($BIOSSetting | Where-Object {$_.Name -eq "Primary Battery Serial Number"}).Value
    $BatteryHealthManager = ($BIOSSetting | Where-Object {$_.Name -eq "Battery Health Manager"}).CurrentValue
    $WakeACDetected = ($BIOSSetting | Where-Object {$_.Name -eq "Wake When AC is Detected"}).CurrentValue
    $WakeLidOpened = ($BIOSSetting | Where-Object {$_.Name -eq "Wake when Lid is Opened"}).CurrentValue
    $PowerOnACDetected = ($BIOSSetting | Where-Object {$_.Name -eq "Power On When AC Detected"}).CurrentValue
    $PowerOnLidOpened = ($BIOSSetting | Where-Object {$_.Name -eq "Power On When Lid is Opened"}).CurrentValue
    $UEFIBoot = ($BIOSSetting | Where-Object {$_.Name -eq "UEFI Boot Options"}).CurrentValue
    $RestrictUSBDevices = ($BIOSSetting | Where-Object {$_.Name -eq "Restrict USB Devices"}).CurrentValue
    $PXEBoot = ($BIOSSetting | Where-Object {$_.Name -eq "Network (PXE) Boot"}).CurrentValue
    $USBStorageBoot = ($BIOSSetting | Where-Object {$_.Name -eq "USB Storage Boot"}).CurrentValue

    <#
    $HPBIOSSettings = Get-CimInstance -Namespace $namespace -ClassName $classname | Select-Object -Property DisplayInUI, IsReadOnly, Name, Path, Value, CurrentValue, Active
	$TempBIOSSettingArray = @()
	foreach ($Setting in $HPBIOSSettings) {
		$tempbios = New-Object -TypeName PSObject
        $tempbios | Add-Member -MemberType NoteProperty -Name "Name" -Value $Setting.Name -Force		
        $tempbios | Add-Member -MemberType NoteProperty -Name "DisplayInUI" -Value $Setting.DisplayInUI -Force
		$tempbios | Add-Member -MemberType NoteProperty -Name "IsReadOnly" -Value $Setting.IsReadOnly -Force		
		$tempbios | Add-Member -MemberType NoteProperty -Name "Path" -Value $Setting.Publisher -Force
		$tempbios | Add-Member -MemberType NoteProperty -Name "Value" -Value $Setting.Value -Force
		$tempbios | Add-Member -MemberType NoteProperty -Name "CurrentValue" -Value $Setting.CurrentValue -Force
        $tempbios | Add-Member -MemberType NoteProperty -Name "Active" -Value $Setting.Active -Force
		$TempBIOSSettingArray += $tempbios
	}
    #>
	$BIOSInventory = New-Object -TypeName PSObject
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
	#$BIOSInventory | Add-Member -MemberType NoteProperty -Name "BIOSSettings" -Value $TempBIOSSettingArray -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "ProductName" -Value "$ProductName" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value "$SerialNumber" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "BornOnDate" -Value "$BornOnDate" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "VTX" -Value "$VTX" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "VTd" -Value "$VTd" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "PPI" -Value "$PPI" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "TPMActivationPolicy" -Value "$TPMActivationPolicy" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "LockBIOSVersion" -Value "$LockBIOSVersion" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "AutomaticBIOSUpdate" -Value "$AutomaticBIOSUpdate" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "NativeOSFirmwareUpdateService" -Value "$NativeOSFirmwareUpdateService" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "BatterySafetyMode" -Value "$BatterySafetyMode" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "PrimaryBatterySerialNumber" -Value "$PrimaryBatterySerialNumber" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "BatteryHealthManager" -Value "$BatteryHealthManager" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "WakeOnLAN" -Value "$WakeOnLAN" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "WakeACDetected" -Value "$WakeACDetected" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "WakeLidOpened" -Value "$WakeLidOpened" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "PowerOnACDetected" -Value "$PowerOnACDetected" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "PowerOnLidOpened" -Value "$PowerOnLidOpened" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "RestrictUSBDevices" -Value "$RestrictUSBDevices" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "UEFIBoot" -Value "$UEFIBoot" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "PXEBoot" -Value "$PXEBoot" -Force
    $BIOSInventory | Add-Member -MemberType NoteProperty -Name "USBStorageBoot" -Value "$USBStorageBoot" -Force
    $HPBIOSSettingInventory = $BIOSInventory
}
#endregion HPBIOSINVENTORY

#region HPBIOSStringINVENTORY
if ($CollectHPBIOSStringInventory) {
	
	#Get BIOS Info from WMI
    $namespace = "ROOT\HP\InstrumentedBIOS"
	$classname = "HP_BIOSString"
    $HPBIOSString = Get-CimInstance -Namespace $namespace -ClassName $classname | Select-Object -Property DisplayInUI, IsReadOnly, Name, Path, Value, Active
	
	$TempBIOSStringArray = @()
	foreach ($Setting in $HPBIOSString) {
		$tempbios = New-Object -TypeName PSObject
		#$tempbios | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
		#$tempbios | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
		#$tempbios | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
		#$tempbios | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
        $tempbios | Add-Member -MemberType NoteProperty -Name "Name" -Value $Setting.Name -Force		
        $tempbios | Add-Member -MemberType NoteProperty -Name "DisplayInUI" -Value $Setting.DisplayInUI -Force
		$tempbios | Add-Member -MemberType NoteProperty -Name "IsReadOnly" -Value $Setting.IsReadOnly -Force		
		$tempbios | Add-Member -MemberType NoteProperty -Name "Path" -Value $Setting.Publisher -Force
		$tempbios | Add-Member -MemberType NoteProperty -Name "Value" -Value $Setting.Value -Force
        $tempbios | Add-Member -MemberType NoteProperty -Name "Active" -Value $Setting.Active -Force
		$TempBIOSStringArray += $tempbios
	}
	
    $BIOSInventory = New-Object -TypeName PSObject
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
	$BIOSInventory | Add-Member -MemberType NoteProperty -Name "BIOSStrings" -Value $TempBIOSStringArray -Force

    $HPBIOSStringInventory = $BIOSInventory

}
#endregion HPBIOSStringINVENTORY

#region HPDockINVENTORY
if ($CollectHPDockInventory){
    # Function to get HP Dock info - Calling from GitHub
    Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1")
    
    #Install WMI Provider for Dock if Needed
    $WMIProvider = Get-InstalledApplications | Where-Object {$_.DisplayName -match 'HP Dock'}
    if (!($WMIProvider)){Get-Softpaq -Number sp142311 -Action silentinstall}

    #Query WMI Provider for Dock Info:
    [String]$Namespace = "HP\InstrumentedServices\v1"
    $classname = "HP_DockAccessory"
    $ConnectedDock = Get-CimInstance -Class $classname  -Namespace "Root\$namespace" -ErrorAction SilentlyContinue
    
    #Check if Dock connected that isn't supported by WMI Provider
    $DockUpdateDetails = Get-HPDockUpdateDetails

    #If no dock found, don't collect anything!
    if (!($ConnectedDock) -and !($DockUpdateDetails)){
        $CollectHPDockInventory = $false
    }
    
    #If Dock found, collect the info!
    else {

        If ($ConnectedDock){
            $ProductName = $ConnectedDock.ProductName
            $FirmwareVersion = $ConnectedDock.FirmwarePackageVersion
            $SerialNumber = $ConnectedDock.SerialNumber
            $UpdateRequired = $DockUpdateDetails.UpdateRequired
            $SoftpaqNumber = $DockUpdateDetails.SoftpaqNumber
            $SoftpaqFimware = $DockUpdateDetails.SoftpaqFirmware
        }
        else {
            $ProductName = $DockUpdateDetails.Dock
            $FirmwareVersion = ($DockUpdateDetails.InstalledFirmware).Trim()
            $SerialNumber = "NA"
            $UpdateRequired = $DockUpdateDetails.UpdateRequired
            $SoftpaqNumber = $DockUpdateDetails.SoftpaqNumber
            $SoftpaqFimware = $DockUpdateDetails.SoftpaqFirmware        
        }
    
        $DockInventory = New-Object -TypeName PSObject
        $DockInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	    $DockInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
	    $DockInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	    $DockInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
        $DockInventory | Add-Member -MemberType NoteProperty -Name "ProductName" -Value $ProductName -Force	
        $DockInventory | Add-Member -MemberType NoteProperty -Name "InstalledFirmware" -Value $FirmwareVersion -Force	
        $DockInventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value $SerialNumber -Force	
        $DockInventory | Add-Member -MemberType NoteProperty -Name "UpdateAvailable" -Value $UpdateRequired -Force	
        $DockInventory | Add-Member -MemberType NoteProperty -Name "LatestSoftpaq" -Value $SoftpaqNumber -Force	
        $DockInventory | Add-Member -MemberType NoteProperty -Name "SoftpaqFirmware" -Value $SoftpaqFimware -Force
    }	
}

#endregion HPDockINVENTORY



if ($CollectHPBIOSSettingInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$HPBIOSSettingLogName = $HPBIOSSettingInventory}
}

if ($CollectHPBIOSStringInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$HPBIOSStringLogName = $HPBIOSStringInventory}
}

if ($CollectHPDockInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$HPDockLogName = $DockInventory}
}
