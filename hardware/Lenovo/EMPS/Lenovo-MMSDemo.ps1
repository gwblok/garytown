#Load Lenovo EMPS

Write-Host "Loading Lenovo EMPS module..." -ForegroundColor Green
Write-Host 'iex (irm lenovo.garytown.com)' -ForegroundColor Cyan

iex (irm lenovo.garytown.com)

Write-Host "Import the Lenovo Module..." -ForegroundColor Green
Write-Host 'Import-ModuleLenovoCSM' -ForegroundColor Cyan
Import-ModuleLenovoCSM

#Pause The Script 
Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host

write-host "Loading Lenovo EMPS module..." -ForegroundColor Green