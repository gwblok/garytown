$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Manufacturer = $Manufacturer"
if ($Manufacturer -match "Lenovo"){
    iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Install-LenovoApps.ps1)
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
}

#Function to install Lenovo CMSL
Function Import-ModuleLenovoCMSL {
  
  $URL = "https://download.lenovo.com/cdrt/tools/Lenovo.Client.Scripting_2.1.0.zip"
  $Destination = "$env:programdata\CMSL\Lenovo.Client.Scripting_2.1.0.zip"
  $ExtractedFolder = "$env:programdata\CMSL\Lenovo.Client.Scripting_2.1.0"

  
  if (!(Test-Path -Path $ExtractedFolder)){
    New-Item -Path $ExtractedFolder -ItemType Directory | Out-Null
  }
  if (!(Test-Path -Path $Destination)){
    Start-BitsTransfer -Source $URL -Destination $Destination -DisplayName "Lenovo CMSL Download"
  }
  Expand-Archive -Path $Destination -DestinationPath $ExtractedFolder -Force
  $LenovoModule = Get-ChildItem -Path $ExtractedFolder -Recurse | Where-Object { $_.Name -eq "Lenovo.Client.Scripting.psm1" } 
  Import-Module -Name $LenovoModule.FullName -Force -Verbose
}
