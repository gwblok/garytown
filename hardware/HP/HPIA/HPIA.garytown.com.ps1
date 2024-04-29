Write-Host "Creating HPIA Functions" -ForegroundColor Green
Write-Host " [+] Write-CMTraceLog" -ForegroundColor Gray
Write-Host " [+] Get-HPIALatestVersion" -ForegroundColor Gray
Write-Host " [+] Install-HPIA" -ForegroundColor Gray
Write-Host " [+] Invoke-HPIA" -ForegroundColor Gray
Write-Host " [+] Get-HPIAXMLResult" -ForegroundColor Gray
Write-Host " [+] Get-HPIAJSONResult" -ForegroundColor Gray
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Invoke-HPIA.ps1)

Write-Host ""
write-host "Demo Functions" -ForegroundColor Green
Write-Host " [+] Get-MMSDemo1" -ForegroundColor Gray
Write-Host " [+] Get-MMSDemo2" -ForegroundColor Gray
Write-Host " [+] Get-MMSDemo3" -ForegroundColor Gray
iex (irm mms24demo.garytown.com)

