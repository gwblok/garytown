<# Gary Blok - @gwblok - GARYTOWN.COM

Get-HardwareDevicesAndDrivers

25.5.12 - Adopted for Task Sequence PowerShell Step
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp"
)

Function Get-HardwareDevicesAndDrivers {
    try {
        $devices = Get-CimInstance -ClassName Win32_PnPSignedDriver | Select-Object DeviceName, DriverVersion, Manufacturer, DriverProviderName, DriverDate

        if ($devices) {
            Write-Output "Hardware Devices and Associated Drivers:"
            foreach ($device in $devices) {
                Write-Output "Device: $($device.DeviceName)"
                Write-Output "  Manufacturer: $($device.Manufacturer)"
                Write-Output "  Driver Version: $($device.DriverVersion)"
                Write-Output "  Driver Provider: $($device.DriverProviderName)"
                Write-Output "  Driver Date: $($device.DriverDate)"
                Write-Output ""
            }
        } else {
            Write-Output "No hardware devices or drivers found."
        }
    } catch {
        Write-Output "Error retrieving hardware devices and drivers: $($_.Exception.Message)"
    }
}


#Create log directory if it doesn't exist
if (Test-Path -path $logPath) {
    Write-Output "Log directory already exists: $logPath"
} else {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    Write-Output "Created log directory: $logPath"
}

#Create Logs with Information
Get-HardwareDevicesAndDrivers | Out-File -FilePath "$logPath\HardwareDevicesAndDrivers.log" -Append -Force
