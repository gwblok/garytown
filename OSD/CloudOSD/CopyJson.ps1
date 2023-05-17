<# Add JSON MDT
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

#>

$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment
$OSDisk = $tsenv.value("osdisk")


#Download WallPaper from GitHub
$JSONURL = "https://github.com/gwblok/garytown/raw/master/OSD/CloudOSD/Pilot.json"
Invoke-WebRequest -UseBasicParsing -Uri $JSONURL -OutFile "$env:TEMP\Pilot.json"

#Copy the JOSN file into place
if (Test-Path -Path "$env:TEMP\Pilot.json"){
    Write-Output "Running Command: Copy-Item .\Pilot.json $OSDisk\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json -Force -Verbose"
    Copy-Item "$env:TEMP\Pilot.json" "$OSDisk\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json" -Force -Verbose
    }
else
    {
    Write-Output "Did not find Pilot.json in temp folder - Please confirm URL"
    }


exit $exitcode
