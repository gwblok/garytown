#Code 100% from https://github.com/byteben/MEM/blob/main/Create-IntuneExtendedLogging.ps1
#Thanks Ben!

# Define the registry path
$regPath = "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging"
$regValues = @("LogMaxHistory,4", "LogMaxSize,4194304") # 4 logs at 4MB each

# Check if the path exists, if not, create it
if (-not (Test-Path -Path $regPath)) {
    Try {
        New-Item -Path $regPath -Force -ErrorAction Stop
    }
    Catch {
        Write-Warning ("Unable to create registry path {0}: {1}" -f $regPath, $_.Exception.Message)
    }
}

# Create or set the registry values
Try {
    Foreach ($reg in $regValues) {
        $name, $value = $reg -split ','
        New-ItemProperty -Path $regPath -Name $name -Value $value -PropertyType "String" -Force -ErrorAction Stop
    }
}
Catch {
    Write-Warning ("Unable to create registry value {0} at {1}: {2}" -f $name, $regPath, $_.Exception.Message)
}
