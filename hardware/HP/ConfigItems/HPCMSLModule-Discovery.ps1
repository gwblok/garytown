#2020.04.20 - @gwblok - GARYTOWN.COM
#Discovery Script
$ModuleName = "HPCMSL"

#No Changes Below this Point ----------------------------
[version]$RequiredVersion = (Find-Module -Name $ModuleName).Version
$InstalledVersion = [Version](Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue).Version
if (!($InstalledVersion)){$InstalledVersion = '1.0.0.1'}
if ($InstalledVersion -ge $RequiredVersion){Write-Output "Compliant"}
else{Write-Output "Version: $InstalledVersion"}
