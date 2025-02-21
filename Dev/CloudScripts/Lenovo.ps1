$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Model
Write-Output "Manufacturer = $Manufacturer | Model = $Model"
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

