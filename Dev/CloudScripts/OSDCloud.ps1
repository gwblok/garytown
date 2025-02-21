$ComputerSystem = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem
$Manufacturer = $ComputerSystem.Manufacturer
$Model = $ComputerSystem.Model
$Serial = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_BIOS | Select-Object -ExpandProperty SerialNumber
Write-Output "Manufacturer = $Manufacturer | Model = $Model"
Write-Host -ForegroundColor DarkGray "==============================================="
Write-Host -ForegroundColor Cyan "   Functions to fun during OSDCloud"
Write-Host -ForegroundColor DarkGray "==============================================="
Write-Host ""
Write-Host -ForegroundColor Green "[+] Function Copy-OSDCloudLogs2OSDCloudUSB"
function Copy-OSDCloudLogs2OSDCloudUSB {
		$OSDCloudLogs = "C:\OSDCloud\Logs"
		$OSDCloudUSB = (Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1).DriveLetter
		if ($OSDCloudUSB){
				$OSDCloudUSBFolder = "$($OSDCloudUSB):\OSDCloud\Logs\$Manufacturer-$Model-$Serial"
				if (!(Test-Path $OSDCloudUSBFolder)) {
						New-Item -Path $OSDCloudUSBFolder -ItemType Directory -Force | Out-Null
				}
				Write-Host "Copying OSDCloud Logs to $OSDCloudUSBFolder"
				Copy-Item -Path $OSDCloudLogs -Destination $OSDCloudUSBFolder -Recurse -Force
		}
}


$namespace = "ROOT\HP\InstrumentedBIOS"
$classname = "HP_BIOSEnumeration"
if (Get-CimInstance -ClassName $classname -Namespace $namespace | Where-Object {$_.Name -match "Enhanced BIOS Authentication"}){
	$HPSureAdminState = Get-HPSureAdminState -ErrorAction SilentlyContinue
	Write-Output "SureAdminState = $HPSureAdminState"
}
else{
	Write-Output "SureAdminState = Feature Not Available"
}