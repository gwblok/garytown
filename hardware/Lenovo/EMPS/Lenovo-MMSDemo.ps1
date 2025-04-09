#Load Lenovo EMPS

Write-Host "Loading Lenovo EMPS module..." -ForegroundColor Green
Write-Host 'iex (irm lenovo.garytown.com)' -ForegroundColor Cyan

iex (irm lenovo.garytown.com)

Write-Host "Import the Lenovo Module..." -ForegroundColor Green
Write-Host 'Import-ModuleLenovoCSM' -ForegroundColor Cyan
Import-ModuleLenovoCSM
Write-Host ""
#Pause The Script 
Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
Write-Host ""
write-host "Listing Lenovo Functions" -ForegroundColor Green
get-command -Module Lenovo.Client.Scripting
Write-Host ""
Read-Host
Write-Host "Lets Run Several and see what they respond with" -ForegroundColor Magenta
Write-Host ""
Write-Host "Get-LnvMachineType          | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvMachineType)"
Write-Host "Get-LnvModelName            | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvModelName)"
Write-Host "Get-LnvProductNumber        | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvProductNumber )"
Write-Host "Get-LnvSerial               | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvSerial)"
Write-Host "Get-LnvBiosCode             | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosCode)"
Write-Host "Get-LnvBiosPasswordsSet     | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosPasswordsSet)"
Write-Host "Get-LnvBiosUpdateUrl        | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosUpdateUrl)"
Write-Host "Get-LnvBiosVersion          | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosVersion)"

Write-Host ""
Read-Host

Write-Host "Get-LnvAvailableBiosVersion" -ForegroundColor Green
Get-LnvAvailableBiosVersion

Write-Host ""
Read-Host

Write-Host "Get-LnvBiosInfo" -ForegroundColor Green
Get-LnvBiosInfo

Write-Host ""
Read-Host

Write-Host "Get-LnvDriverPack" -ForegroundColor Green
Get-LnvDriverPack

Write-Host ""
Read-Host

Write-Host "Get-LnvDriverPack" -ForegroundColor Green
Get-LnvDriverPack

Write-Host ""
Read-Host
