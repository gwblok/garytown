#Functions for HP Computers

#HP CMSL WinPE replacement
Write-Host -ForegroundColor Cyan " ** Custom EMPS Functions for WinPE **"
Write-Host -ForegroundColor Green "[+] Function Get-HPOSSupport"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqListLatest"
Write-Host -ForegroundColor Green "[+] Function Get-HPSoftpaqItems"
Write-Host -ForegroundColor Green "[+] Function Get-HPDriverPackLatest"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Test-HPIASupport.ps1)

Write-Host -ForegroundColor Cyan " ** HPIA Functions **"
Write-Host -ForegroundColor Green "[+] Function Get-HPIALatestVersion"
Write-Host -ForegroundColor Green "[+] Function Install-HPIA"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPIA"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAXMLResult"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAJSONResult"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/HPIA/HPIA-Functions.ps1)

Write-Host -ForegroundColor Cyan " ** HP TPM Functions [TPM 1.2 -> 2.0] **"
Write-Host -ForegroundColor Green "[+] Function Get-HPTPMDetermine"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMDownload"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMDowngrade"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMEXEDownload"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMEXEInstall"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Get-HPTPMDetermine.ps1)

Write-Host -ForegroundColor Cyan " ** Other Functions for HP **"
Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)
Write-Host -ForegroundColor Green "[+] Function Manage-HPBiosSettings [https://www.configjon.com/hp-bios-settings-management]"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)

#Install-ModuleHPCMSL
Write-Host -ForegroundColor Green "[+] Function Install-ModuleHPCMSL"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/EMPS/Install-ModuleHPCMSL.ps1)
Write-Host -ForegroundColor Green "[+] Function Invoke-HPAnalyzer"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPDriverUpdate"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/EMPS/Invoke-HPDriverUpdate.ps1)

#Demo for MMS:
Write-Host -ForegroundColor Green "[+] Function Invoke-MMSDemo2025"
function Invoke-MMSDemo2025 {
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/HP/EMPS/HP-MMSDemo.ps1')
}
