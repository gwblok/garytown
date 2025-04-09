$ComputerSystem = (Get-CimInstance -ClassName Win32_ComputerSystem)
$Manufacturer = ($ComputerSystem).Manufacturer
$Model = ($ComputerSystem).Model
$SystemSKUNumber = ($ComputerSystem).SystemSKUNumber
$SerialNumber = Get-CimInstance -ClassName Win32_BIOS | Select-Object -ExpandProperty SerialNumber


Write-Host -ForegroundColor Cyan "Manufacturer:       " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Manufacturer"
Write-Host -ForegroundColor Cyan "Model:              " -NoNewline ; Write-Host  -ForegroundColor Yellow "$Model"
#Write-Host -ForegroundColor Cyan "System SKU Number:  " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SystemSKUNumber"
Write-Host -ForegroundColor Cyan "Serial Number:      " -NoNewline ; Write-Host  -ForegroundColor Yellow "$SerialNumber"

Write-host -ForegroundColor Cyan "Calling Lenovo-CSM script on GARYTOWN GitHub"
Write-Host "https://github.com/gwblok/garytown/blob/master/hardware/Lenovo/EMPS/Lenovo-EMPS.ps1"
Write-Host ""
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/EMPS/Lenovo-EMPS.ps1)
Write-Host -ForegroundColor Green "[+] Import-ModuleLenovoCSM (2.1.0)"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoVantage (-IncludeSUHelpoer)"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantage"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageSU"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageAutoUpdates"
Write-Host -ForegroundColor Green "[+] Function Reset-LenovoVantageSettings"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoSystemUpdaterLogging"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoThinInstaller"
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoThinInstaller"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoBackgroundMonitorDisabled"
Write-Host -ForegroundColor Green "[+] Function Invoke-SUHelper(BIOSUpdates)"
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

