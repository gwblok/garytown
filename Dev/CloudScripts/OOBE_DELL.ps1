$ScriptName = 'dell.garytown.com'
$ScriptVersion = '25.11.17.16.14'

#region Initialize

$ComputerSystem = (Get-CimInstance -ClassName Win32_ComputerSystem)
$Manufacturer = ($ComputerSystem).Manufacturer
$Model = ($ComputerSystem).Model
$SystemSKUNumber = ($ComputerSystem).SystemSKUNumber
$SerialNumber = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SerialNumber

#Command Update Scripts
Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPS.ps1')
Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPSWarranty.ps1')

#Native WMI BIOS Functions
Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/2PintLabs/refs/heads/main/DeployR/BIOSSettings/Dell/NativeWMI/SetDellBIOSSettingsWMI-Functions.ps1')


Write-Host -ForegroundColor Green "[+] Function Invoke-MMSDemo2025"
function Invoke-MMSDemo2025 {
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Dell/CommandUpdate/EMPS/Dell-MMSDemo.ps1')
}

Write-Host -ForegroundColor Cyan "Manufacturer:       " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Manufacturer"
Write-Host -ForegroundColor Cyan "Model:              " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Model"
Write-Host -ForegroundColor Cyan "System SKU Number:  " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SystemSKUNumber"
Write-Host -ForegroundColor Cyan "Serial Number:      " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SerialNumber"
Write-Host ""
Write-Host "Functions For Dell Command Update and Dell Device Details:" -ForegroundColor Magenta
Write-Host -ForegroundColor Green "[+] Function: Get-DellDeviceDetails"
Write-Host -ForegroundColor Green "[+] Function: Get-DellDeviceDriverPack"
Write-Host -ForegroundColor Green "[+] Function: Get-DellSupportedModels"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUVersion"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUInstallDetails"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUExitInfo"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUAppUpdates"
#Write-Host -ForegroundColor Green "[+] Function: Install-DCU"
Write-Host -ForegroundColor Green "[+] Function: Set-DCUSettings"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUSettings"
Write-Host -ForegroundColor Green "[+] Function: Invoke-DCU"
Write-Host -ForegroundColor Green "[+] Function: Get-DCUUpdateList"
#Write-Host -ForegroundColor Green "[+] Function: New-DCUCatalogFile"
#Write-Host -ForegroundColor Green "[+] Function: New-DCUOfflineCatalog"
Write-Host -ForegroundColor Green "[+] Function: Get-DellBIOSUpdates"
Write-Host -ForegroundColor Green "[+] Function: Get-DellWarrantyInfo (-Cleanup)" #Temporarily Installs Dell Command Integration Suite to gather warranty info
#Write-Host -ForegroundColor Green "[+] Function: Invoke-DellIntuneAppPublishScript" #Not yet implemented
Write-Host -ForegroundColor DarkGray "----------------------------------------"
Write-Host -ForegroundColor Magenta "Dell BIOS Functions:"
Write-Host -ForegroundColor Green "[+] Function: Test-DellBIOSWMISupport - Verifies if the device supports Dell BIOS WMI management (devices 2018+)"
Write-Host -ForegroundColor Green "[+] Function: Test-DellBIOSPassword - Checks if a BIOS Admin or System password is currently set"
Write-Host -ForegroundColor Green "[+] Function: Get-DellBIOSSetting - Retrieves BIOS settings from the device (all settings or specific setting)"
Write-Host -ForegroundColor Green "[+] Function: Set-DellBIOSSetting - Modifies BIOS settings with automatic password detection"
Write-Host -ForegroundColor Green "[+] Function: Set-DellBIOSAdminPassword - Simplified function to set, change, or remove BIOS Admin password"
Write-Host -ForegroundColor DarkGray "----------------------------------------"
