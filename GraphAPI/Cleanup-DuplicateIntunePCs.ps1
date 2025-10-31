<#
.SYNOPSIS
	Cleanup of duplicate Intune devices based on Serial Number

.DESCRIPTION
	This script gets all Intune devices and selects duplicates based on SerialNumber. All duplicates, except for Last Synced device will be removed.

.PARAMETER WhatIf
	Will show the devices that would be removed, but does not remove them.

.PARAMETER Verbose
	Prints out more information

.EXAMPLE
	Remove-DuplicateIntuneDevices -Whatif 

	Will show the devices that would be removed, but does not remove them.

.EXAMPLE
	Remove-DuplicateIntuneDevices

	This command removes duplicate devices based on the serial number.
	You will be prompted for confirmation before each device is deleted 

.EXAMPLE 
	Remove-DuplicateIntuneDevices -Confirm:$false

	This command automatically removes duplicate devices based on the serial number.
	You will NOT be prompted for confirmation !! 

.NOTES
	Author:           Tobias Putman-Barth

.LINK
	https://configchronicles.com/removing-duplicate-intune-devices/
	
#>
[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='High')]
Param()
Begin {
	Set-StrictMode -Version 3.0
	Write-Host "Starting Remove-DuplicateIntuneDevices"
	Write-Verbose "Checking if Microsoft.Graph.Intune module is installed"
	try {
		Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop
	}
	catch {
		Write-Error "Module Microsoft.Graph.Intune not found. Please install module."
		exit 1
	}

	Write-Verbose "Connect to Intune"
	try{
		Connect-MgGraph -NoWelcome -Scopes 'DeviceManagementManagedDevices.ReadWrite.All' -ErrorAction stop
	}
	catch{
		Write-iError "Not authenticated. Please authenticate and connect to intune with an account with sufficient privileges."
		exit 1
	}
}
Process {
	#Get all intune devices
	$devices = Get-MgDeviceManagementManagedDevice -All
	Write-Verbose "Found $($devices.Count) devices."

	#Place devices in groups
	$deviceGroups = $devices | Where-Object { -not [String]::IsNullOrWhiteSpace($_.serialNumber) -and ($_.serialNumber -ne "Defaultstring")} | Group-Object -Property serialNumber
	
	#filter out groups with more than one entry
	$duplicatedDevices = $deviceGroups | Where-Object {$_.Count -gt 1 }
	if ($null -ne $duplicatedDevices){
		Write-Verbose "Found $($duplicatedDevices.Values.Count) devices with duplicated entries"
		Write-Host "Processing removal of $($duplicatedDevices.Values.Count) duplicate devices"
	}
	
	$DuplicatesDeleted = 0
	
	foreach($duplicatedDevice in $duplicatedDevices){
		#find devices to delete, skip the first entry of the group as that is the most recently synced device
		$devicesToDelete = $duplicatedDevice.Group | Sort-Object -Property lastSyncDateTime -Descending | Select-Object -Skip 1
		Write-Verbose "Selected duplicate device: $($duplicatedDevice.DeviceName)"
		
		foreach($device in $devicesToDelete){
			if($PSCmdlet.ShouldProcess("$($device.SerialNumber), $($device.LastSyncDateTime)", "Remove device from intune")){
				Write-Verbose "Removing $($device.deviceName) $($device.lastSyncDateTime)"
				try {
					Remove-MgDeviceManagementManagedDevice -managedDeviceId $device.id
					Write-Verbose "Device $($device.deviceName) $($device.lastSyncDateTime) deleted"
					$DuplicatesDeleted++
				}
				catch {
					Write-Error "Could not delete device: $($device.deviceName) $($device.lastSyncDateTime)"
				}
			} 
			else{
				Write-Verbose "Device $($device.deviceName), last synced on $($device.lastSyncDateTime) set to be deleted if script is run"
			}
		}
	}
}
End {
	Disconnect-MgGraph | Out-Null
	Write-Host "Done. $DuplicatesDeleted devices deleted."
}