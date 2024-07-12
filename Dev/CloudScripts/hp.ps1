#Functions for HP Computers

#HP CMSL WinPE replacement
Write-Host -ForegroundColor Cyan " ** Custom CMSL Functions for WinPE **"
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
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Invoke-HPIA.ps1)

Write-Host -ForegroundColor Cyan " ** HP TPM Functions [TPM 1.2 -> 2.0] **"
Write-Host -ForegroundColor Green "[+] Function Get-HPTPMDetermine"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMDownload"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMDowngrade"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMEXEDownload"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPTPMEXEInstall"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Get-HPTPMDetermine.ps1)

Write-Host -ForegroundColor Cyan " ** Other Functions for HP **"
Write-Host -ForegroundColor Green "[+] Function Manage-HPBiosSettings"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)
#Install-ModuleHPCMSL
Write-Host -ForegroundColor Green "[+] Function Install-ModuleHPCMSL"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Install-ModuleHPCMSL.ps1)
Write-Host -ForegroundColor Green "[+] Function Invoke-HPAnalyzer"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPDriverUpdate"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Invoke-HPDriverUpdate.ps1)
