$ScriptName = 'dell.garytown.com'
$ScriptVersion = '24.06.10.01'

#region Initialize


$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber

Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate/CMSL/Dell-CMSL.ps1')

if ($Manufacturer -match "Dell"){
    $Manufacturer = "Dell"
    
    write-output "Manufacturer:    $Manufacturer"
    write-output "Model:           $Model"
    write-output "SystemSKUNumber: $SystemSKUNumber"
    
    $DellEnterprise = Test-DCUSupport
    if ($DellEnterprise -eq $true) {
        Write-Host "Running $ScriptName - $ScriptVersion" -ForegroundColor Green
        Write-Host -ForegroundColor Green "Dell System Supports Dell Command Update"
        Write-Host -ForegroundColor Green " Enabling Dell Functions: https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1"
        Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1')
        Write-Host -ForegroundColor Green "[+] Funciton: osdcloud-InstallDCU"
        Write-Host -ForegroundColor Green "[+] Function: osdcloud-RunDCU"
        Write-Host -ForegroundColor Green "[+] Function: osdcloud-RunDCU"
        
    } 
}
