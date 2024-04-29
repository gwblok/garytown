Write-Host "Creating HPIA Functions" -ForegroundColor Green
Write-Host " [+] Write-CMTraceLog" -ForegroundColor Gray
Write-Host " [+] Get-HPIALatestVersion" -ForegroundColor Gray
Write-Host " [+] Install-HPIA" -ForegroundColor Gray
Write-Host " [+] Invoke-HPIA" -ForegroundColor Gray
Write-Host " [+] Get-HPIAXMLResult" -ForegroundColor Gray
Write-Host " [+] Get-HPIAJSONResult" -ForegroundColor Gray
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Invoke-HPIA.ps1)


write-host "Demo Commands" -ForegroundColor Green
Write-host ' cd c:\temp' -ForegroundColor Gray
Write-host ' Get-HPDeviceDetails -like *"840 G10"*"' -ForegroundColor Gray
Write-host ' Get-HPDeviceDetails -like *"800*G9"*' -ForegroundColor Gray
Write-host ' $Platforms = @("8B41", "8AC3")' -ForegroundColor Gray
Write-host ' $DPs = $Platforms | foreach {Get-SoftpaqList -Category Driverpack -Os win11 -OsVer 22H2 -Platform $_}' -ForegroundColor Gray
Write-host ' $DPs | foreach {Get-Softpaq -Number $_.id -Extract}' -ForegroundColor Gray
Write-host '' -ForegroundColor Gray
Write-host '' -ForegroundColor Gray
