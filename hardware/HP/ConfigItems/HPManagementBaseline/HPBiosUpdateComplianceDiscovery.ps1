<#Detection on CI:
#Requires HPCMSL already Installed.
$HPCMSLVers = Get-InstalledModule -Name "HPCMSL" -ErrorAction SilentlyContinue
if ((Get-CimInstance -Namespace root/cimv2 -ClassName Win32_ComputerSystem).Manufacturer -like "H*"){$IsHP = $true}

if ($HPCMSLVers -ne $Null -and $IsHP -eq $true)
    {
    Write-Output "HP with HPCMSL"
    }
#>
#Discovery Script Below:
#Check if HP Bios is Current

[version]$BIOSVersionInstalled = Get-HPBIOSVersion
[version]$BIOSVersionAvailableOnline = (Get-HPBIOSUpdates -latest).Ver

if ($BIOSVersionInstalled -lt $BIOSVersionAvailableOnline)
    {Write-Output "Has $($BIOSVersionInstalled), Needs: $($BIOSVersionAvailableOnline)"}
else {Write-Output "Compliant"}
