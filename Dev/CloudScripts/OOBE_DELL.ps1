$ScriptName = 'dell.garytown.com'
$ScriptVersion = '24.06.10.01'

#region Initialize


$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber


if ($Manufacturer -match "Dell"){
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate/CMSL/Dell-CMSL.ps1')

    $Manufacturer = "Dell"
    write-output "Manufacturer:    $Manufacturer"
    write-output "Model:           $Model"
    write-output "SystemSKUNumber: $SystemSKUNumber"
    
    Write-Host -ForegroundColor Green "[+] Function: Get-DellSupportedModels"
    Write-Host -ForegroundColor Green "[+] Function: Get-DCUVersion"
    Write-Host -ForegroundColor Green "[+] Function: Get-DCUInstallDetails"
    Write-Host -ForegroundColor Green "[+] Function: Get-DCUExitInfo"
    Write-Host -ForegroundColor Green "[+] Function: Install-DCU"
    Write-Host -ForegroundColor Green "[+] Function: Invoke-DCU"
    Write-Host -ForegroundColor Green "[+] Function: Get-DCUUpdateList"
    Write-Host -ForegroundColor Green "[+] Function: Get-DellDeviceDetails"
    
}
