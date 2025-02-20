$ScriptName = 'dell.garytown.com'
$ScriptVersion = '25.2.7.1'

#region Initialize


$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber



Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPS.ps1')
Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPSWarranty.ps1')


write-output "Manufacturer:    $Manufacturer"
write-output "Model:           $Model"
write-output "SystemSKUNumber: $SystemSKUNumber"

Write-Host -ForegroundColor Green "[+] Function: Get-DellDeviceDetails"
Write-Host -ForegroundColor Green "[+] Function: Get-DellDeviceDriverPack"
Write-Host -ForegroundColor Green "[+] Function: Get-DellSupportedModels"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUVersion"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUInstallDetails"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUExitInfo"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUAppUpdates"
#Write-Host -ForegroundColor Green "[+] Function: Install-DCU"
Write-Host -ForegroundColor Green "[+] Function: Set-DCUSettings"
Write-Host -ForegroundColor Green "[+] Function: Invoke-DCU"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUUpdateList"
#Write-Host -ForegroundColor Green "[+] Function: New-DCUCatalogFile"
#Write-Host -ForegroundColor Green "[+] Function: New-DCUOfflineCatalog"
Write-Host -ForegroundColor Green "[+] Function: Get-DellBIOSUpdates"
Write-Host -ForegroundColor Green "[+] Function: Get-DellWarrantyInfo"
