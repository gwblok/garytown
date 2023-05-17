<# Gary Blok | @gwblok | GARYTOWN.COM

This just grabs a bunch of information from WMI about the Battery.  Typically this information would be used with other processes.  Just recording where to find the info

#>

$namespace = "ROOT\cimv2"
$EstimatedChargeRemaining = (Get-CimInstance -Namespace $namespace -ClassName "Win32_Battery").EstimatedChargeRemaining
$EstimatedRunTime = (Get-CimInstance -Namespace $namespace -ClassName "Win32_Battery").EstimatedRunTime


$namespace = "ROOT\WMI"
$CycleCount = (Get-CimInstance -Namespace $namespace -ClassName "BatteryCycleCount").CycleCount
$FullChargedCapacity = (Get-CimInstance -Namespace $namespace -ClassName "BatteryFullChargedCapacity").FullChargedCapacity
$EstimatedRuntime2 = (Get-CimInstance -Namespace $namespace -ClassName "BatteryRuntime").EstimatedRuntime
$DesignedCapacity = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").DesignedCapacity
$SerialNumber = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").SerialNumber
$ManufactureName = (Get-WmiObject  -Namespace $namespace -ClassName "BatteryStaticData").ManufactureName
$DischargeRate = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").DischargeRate
$Discharging = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").Discharging
$Charging = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").Charging
$PowerOnline = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").PowerOnline
$Voltage = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").Voltage
$RemainingCapacity = (Get-CimInstance -Namespace $namespace -ClassName "BatteryStatus").RemainingCapacity
$Temperature = (Get-WmiObject -Namespace $namespace -ClassName "BatteryTemperature").Temperature #Doesn't Work

#Device Info
$ManufactureName = (Get-WmiObject  -Namespace $namespace -ClassName "MSBatteryClass").ManufactureName
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
$HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
$Serial = (Get-WmiObject -class:win32_bios).SerialNumber

#Get Battery Temperature
#https://stackoverflow.com/questions/45736193/how-can-we-get-a-cpu-temperature-through-wmi
$Temps = Get-CimInstance -Namespace root/wmi -ClassName MsAcpi_ThermalZoneTemperature -Filter "Active='True' and CurrentTemperature<>2732" -Property InstanceName, CurrentTemperature |
    Select-Object InstanceName, @{n='CurrentTemperatureC';e={'{0:n0}' -f (($_.CurrentTemperature - 2732) / 10.0)}}, @{n='CurrentTemperatureF';e={'{0:n0}' -f ((($_.CurrentTemperature - 2732) / 10.0 *1.8) + 32)}}
$BatteryTemp = $Temps | Where-Object {$_.InstanceName -match "BATZ"}

Write-Host "Device Info" -ForegroundColor Green
Write-Output "Computer Model:   $ComputerModel | $HPProdCode"
#Write-Output "Serial:           $Serial"

Write-Host "Battery Status" -ForegroundColor Green
Write-Output "EstimatedChargeRemaining:  $EstimatedChargeRemaining %"
#These next two are basically the same, but they come from different WMI Namespaces.
if ($Discharging -eq $true){
    Write-Output "EstimatedRunTime:          $EstimatedRunTime minutes" #Win32_Battery
    Write-Output "EstimatedRunTime:          $EstimatedRunTime2 seconds" #BatteryRuntime
}
Write-Output ""


Write-Output "DischargeRate:     $DischargeRate"
Write-Output "Discharging:       $Discharging"
Write-Output "Charging:          $Charging"
Write-Output "PowerOnline:       $PowerOnline"
Write-Output "Voltage:           $Voltage"
Write-Output "Temp:              F: $($BatteryTemp.CurrentTemperatureF) | C: $($BatteryTemp.CurrentTemperatureC)"
Write-Output ""
Write-Host "Battery Design and Capacity Status"  -ForegroundColor Green
Write-Output "DesignedCapacity:    $([math]::Round($DesignedCapacity / 1000)) WHr"
Write-Output "FullChargedCapacity: $([math]::Round($FullChargedCapacity / 1000)) WHr"
Write-Output "RemainingCapacity:   $([math]::Round($RemainingCapacity / 1000)) WHr"
Write-Output "Battery Degraded :   $([math]::Round(100 - (($FullChargedCapacity / $DesignedCapacity)*100))) %"

Write-Output "CycleCount:          $CycleCount"

Write-Output ""
Write-Host "Battery Details"  -ForegroundColor Green
Write-Output "SerialNumber:     $SerialNumber"
Write-Output "ManufactureName:  $ManufactureName"
