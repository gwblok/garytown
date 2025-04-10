$ComputerSystem = (Get-CimInstance -ClassName Win32_ComputerSystem)
$Manufacturer = ($ComputerSystem).Manufacturer
$Model = ($ComputerSystem).Model
$SystemFamily = ($ComputerSystem).SystemFamily
$SerialNumber = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SerialNumber

Write-Host -ForegroundColor Cyan "Manufacturer:       " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Manufacturer"
Write-Host -ForegroundColor Cyan "Model:              " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Model"
Write-Host -ForegroundColor Cyan "System Family:      " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SystemFamily"
Write-Host -ForegroundColor Cyan "Serial Number:      " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SerialNumber"
Write-Host ""
Write-host -ForegroundColor Cyan "Calling Lenovo-CSM script on GARYTOWN GitHub"
Write-Host "https://github.com/gwblok/garytown/blob/master/hardware/Lenovo/EMPS/Lenovo-EMPS.ps1"
Write-Host ""
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/EMPS/Lenovo-EMPS.ps1)
Write-Host -ForegroundColor Green "[+] Import-ModuleLenovoCSM (2.2.0)                    " -NoNewline; Write-Host "Downloads and Installs the Lenovo CSM PS Module" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Install-LenovoVantage (-IncludeSUHelper) " -NoNewline; Write-Host "Downloads and Installs the Lenovo Commercial Vantage" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantage                        " -NoNewline; Write-Host "Configure Settings for LCV" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageSU                      " -NoNewline; Write-Host "Configure Software Update Settings for LCV" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageAutoUpdates             " -NoNewline; Write-Host "Configure Automatic Updates Settings for LCV" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Reset-LenovoVantageSettings              " -NoNewline; Write-Host "Reset LCV Settings to Default" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Install-LenovoSystemUpdater              " -NoNewline; Write-Host "Downloads and Installs the Lenovo System Updater" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoSystemUpdater               " -NoNewline; Write-Host "Triggers the Lenovo System Updater with several parameter options" -ForegroundColor Cyan 
Write-Host -ForegroundColor Green "[+] Function Set-LenovoSystemUpdaterLogging           " -NoNewline; Write-Host "Configure Logging for Lenovo System Updater (Disabled by Default)" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Install-LenovoThinInstaller              " -NoNewline; Write-Host "Downloads and Installs the Lenovo Thin Installer" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoThinInstaller               " -NoNewline; Write-Host "Triggers the Lenovo Thin Installer with several parameter options" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Set-LenovoBackgroundMonitorDisabled      " -NoNewline; Write-Host "Disables the Lenovo Background Monitor Scheduled Task" -ForegroundColor Cyan
Write-Host -ForegroundColor Green "[+] Function Invoke-SUHelper(BIOSUpdates)             " -NoNewline; Write-Host "If BIOS Update available, triggers Toast to interact with End User to Update BIOS" -ForegroundColor Cyan
Write-Host ""
Write-Host -ForegroundColor Magenta "Lenovo Docs for Vantage: https://docs.lenovocdrt.com/guides/cv/commercial_vantage/"
Write-Host -ForegroundColor Magenta "Lenovo Docs for CSM: https://docs.lenovocdrt.com/guides/lcsm/lcsm_top/"
Write-Host ""
Write-Host "For details about the functions, look at the code on GitHub"
Write-Host "For details on how Lenovo Commercial Vantage works, see the Lenovo Docs"
Write-Host ""
Function Set-LenovoBackgroundMonitorDisabled {
  $LenovoBackgroundTask = Get-ScheduledTask -TaskName "Background monitor" -ErrorAction SilentlyContinue
  if ($LenovoBackgroundTask){
      $LenovoBackgroundTask | Disable-ScheduledTask 
  }
}
Function Invoke-SUHelper {
  iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/EMPS/SU-InstallBIOSUpdates.ps1)
}

Function Invoke-MMSDemo2025 {
  iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/EMPS/Lenovo-MMSDemo.ps1)
}

