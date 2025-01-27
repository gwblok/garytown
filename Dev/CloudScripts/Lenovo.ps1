$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Manufacturer = $Manufacturer"
Write-host -ForegroundColor Cyan "Calling Lenovo-CMSL script on GARYTOWN GitHub"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/hardware/Lenovo/CMSL/Lenovo-CMSL.ps1)
Write-Host -ForegroundColor Green "[+] Import-ModuleLenovoCMSL (2.1.0)"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoVantage"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoVantage"
Write-Host -ForegroundColor Green "[+] Function Install-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Invoke-LenovoSystemUpdater"
Write-Host -ForegroundColor Green "[+] Function Set-LenovoBackgroundMonitorDisabled"
Function Set-LenovoBackgroundMonitorDisabled {
  $LenovoBackgroundTask = Get-ScheduledTask -TaskName "Background monitor" -ErrorAction SilentlyContinue
  if ($LenovoBackgroundTask){
      $LenovoBackgroundTask | Disable-ScheduledTask 
  }
}


