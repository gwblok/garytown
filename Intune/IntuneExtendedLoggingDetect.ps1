#Code from https://github.com/byteben/MEM/blob/main/Create-IntuneExtendedLogging.ps1

# Define the registry path
$regPath = "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging"
$regValues = @("LogMaxHistory,4", "LogMaxSize,4194304") # 4 logs at 4MB each

# Check if the path exists, if not, create it
if (-not (Test-Path -Path $regPath)) {
    exit 1
}

# Create or set the registry values
$CurrentRegValues = Get-Item -Path $regPath

Foreach ($reg in $regValues) {
    $name, $value = $reg -split ','
    #Write-Host "Testing $Name for Value: $Value"
    if ($CurrentRegValues.GetValue($name) -ne $value){
        exit 1
    }
}
