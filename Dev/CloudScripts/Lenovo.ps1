$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Manufacturer = $Manufacturer"
Write-host -ForegroundColor Cyan "Calling Lenovo-CMSL script on GARYTOWN GitHub"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/CMSL/Lenovo-CMSL.ps1)
Write-Host -ForegroundColor Green "[+] Import-ModuleLenovoCMSL (2.1.0)"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoVantage"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantage"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageSU"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantageAutoUpdates"
Write-Host -ForegroundColor Green "[+] Function Reset-LenovoVantageSettings"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoBackgroundMonitorDisabled"
Write-Host ""
Write-Host -ForegroundColor Magenta "Lenovo Docs for Vantage: https://docs.lenovocdrt.com/guides/cv/commercial_vantage/"
Write-Host -ForegroundColor Magenta "Lenovo Docs for CMSL: https://docs.lenovocdrt.com/guides/lcsm/lcsm_top/"
Write-Host ""
Write-Host "For details about the functions, look at the code on GitHub"
Write-Host "For details on how Lenovo Commercial Vantage works, see the Lenovo Docs"
Function Set-LenovoBackgroundMonitorDisabled {
  $LenovoBackgroundTask = Get-ScheduledTask -TaskName "Background monitor" -ErrorAction SilentlyContinue
  if ($LenovoBackgroundTask){
      $LenovoBackgroundTask | Disable-ScheduledTask 
  }
}


