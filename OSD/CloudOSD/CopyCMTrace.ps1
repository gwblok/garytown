<# Add CMTrace MDT
Gary Blok @gwblok Recast Software
Used with OSDCloud Edition OSD
#>

#Download WallPaper from GitHub
$CMTraceURL = "https://github.com/gwblok/garytown/raw/master/OSD/CloudOSD/CMTrace.exe"
Invoke-WebRequest -UseBasicParsing -Uri $CMTraceURL -OutFile "$env:TEMP\CMTrace.exe"

#Copy the CMTrace into place
if (Test-Path -Path "$env:TEMP\CMTrace.exe"){
    Write-Output "Running Command: Copy-Item .\CMTrace.exe C:\Windows\system32\CMTrace.exe -Force -Verbose"
    Copy-Item "$env:TEMP\CMTrace.exe" "$env:windir\system32\CMTrace.exe" -Force -Verbose
    }
else
    {
    Write-Output "Did not find CMTrace.exe in temp folder - Please confirm URL"
    }

exit $exitcode
