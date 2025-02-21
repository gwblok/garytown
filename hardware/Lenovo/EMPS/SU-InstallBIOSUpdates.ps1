#Taken directly from the Lenovo SU Helper documentation: https://blog.lenovocdrt.com/su-helper-use-cases-in-a-modern-world/#scenario-on-demand-bios-update

# Define SU Helper variables
$basePath = "$env:ProgramFiles\Lenovo\SUHelper"
$suHelperPath = Join-Path -Path $basePath -ChildPath "SUHelper.exe"
$suParams = @('-autoupdate', '-packagetype', '3') # Specifying Package Type 3 to filter only BIOS updates (https://docs.lenovocdrt.com/guides/cv/suhelper/#-packagetype-string)

# Check if SUHelper.exe exists
if (-Not (Test-Path $suHelperPath))
{
    Write-Error "SUHelper.exe not found at $suHelperPath."
    #exit 1
}

try
{
    # Fetch applicable updates
    $applicableUpdates = Get-CimInstance -Namespace root/Lenovo -ClassName Lenovo_Updates | Where-Object { $_.Status -eq "Applicable" }

    # Check for BIOS update
    $biosUpdateAvailable = $applicableUpdates | Where-Object { $_.Title -match "BIOS" }

    if (-Not $biosUpdateAvailable)
    {
        Write-Output "No BIOS update available."
        exit 0
    }
    else
    {
        Write-Output "BIOS update available to install. Triggering SU Helper."
    }

    # Start the SU Helper process
    $process = Start-Process -FilePath $suHelperPath -ArgumentList $suParams -NoNewWindow -PassThru
    $process.WaitForExit()

    if ($process.ExitCode -ne 0)
    {
        Write-Error "SUHelper.exe exited with code $($process.ExitCode)."
        #exit 1
    }
}
catch
{
    Write-Error "Error occurred: $_"
    #exit 1
}