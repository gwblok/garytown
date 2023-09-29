<#  Addon Enhancement for Batteries using MSEndpointMgr's Enhanced Inventory
https://msendpointmgr.com/2022/01/17/securing-intune-enhanced-inventory-with-azure-function/

I ASSUME you already set that up and have it working, if not, this will not work.  Once you have that setup, you can implement this ADD ON.

Call this script from theirs to add additional inventory into Log Analytics for HP devices.
There Script: (https://github.com/MSEndpointMgr/IntuneEnhancedInventory/blob/main/Proactive%20Remediation/Invoke-CustomInventoryAzureFunction.ps1)

create this line below just before line 551 (<# *SAMPLE*) in the script above.
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Intune/EndMgrEnhancedInventoryAddon_Battery.ps1)

That will call this script


.ChangeLog
      23.09.15.01 - First Release as Addon for Batteries
      23.09.29.01 - Fixed bug, missing line for Remaining Capacity

#>
$CollectBatteryInventory = $true #Sub selection of BIOS Settings I've picked... let me know if you want more.
$BatteryLogName = "BatteryInventory"

#region BatteryInventory

    if ($CollectBatteryInventory){
	    #Get Battery Info from WMI
        $namespace = "ROOT\WMI"
        $ManufactureName = (Get-WmiObject  -Namespace $namespace -ClassName "MSBatteryClass" -ErrorAction SilentlyContinue).ManufactureName
        if ($ManufactureName){
        
            $CycleCount = (Get-CimInstance -Namespace $namespace -ClassName "BatteryCycleCount").CycleCount
            $FullChargedCapacity = (Get-CimInstance -Namespace $namespace -ClassName "BatteryFullChargedCapacity").FullChargedCapacity
            $EstimatedRuntime2 = (Get-CimInstance -Namespace $namespace -ClassName "BatteryRuntime").EstimatedRuntime
            $DesignedCapacity = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").DesignedCapacity
            $SerialNumber = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").SerialNumber
            $ManufactureName = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").ManufactureName
            $RemainingCapacity = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").RemainingCapacity

            $BatteryInventory = New-Object -TypeName PSObject
	        $BatteryInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	        $BatteryInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
	        $BatteryInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	        $BatteryInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force	

            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "DesignedCapacity" -Value "$([math]::Round($DesignedCapacity / 1000)) WHr" -Force
            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "FullChargedCapacity" -Value "$([math]::Round($FullChargedCapacity / 1000)) WHr" -Force	
            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "RemainingCapacity" -Value "$([math]::Round($RemainingCapacity / 1000)) WHr" -Force	
            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "BatteryDegraded" -Value "$([math]::Round(100 - (($FullChargedCapacity / $DesignedCapacity)*100))) %" -Force	
            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "CycleCount" -Value "$CycleCount" -Force	
            $BatteryInventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value "$SerialNumber" -Force	
        }
        else {
            $CollectBatteryInventory = $false
        }
    }
    #endregion BatteryInventory


if ($CollectBatteryInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$BatteryLogName = $BatteryInventory}
}
