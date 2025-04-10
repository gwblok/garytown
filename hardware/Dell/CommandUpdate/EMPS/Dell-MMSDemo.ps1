#Load Dell EMPS
Clear-Host

Write-Host "Loading Dell EMPS module..." -ForegroundColor Green
Write-Host 'iex (irm dell.garytown.com)' -ForegroundColor Cyan

iex (irm dell.garytown.com)


Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
Write-Host "Lets Run Several and see what they respond with" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DellDeviceDetails" -ForegroundColor Green
Get-DellDeviceDetails
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -ModelLike "7520"' -ForegroundColor Cyan
Get-DellDeviceDetails -ModelLike "7520"
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -SystemSKUNumber 0D15' -ForegroundColor Cyan
Get-DellDeviceDetails -SystemSKUNumber 0D15
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -ModelLike "pro" | Where-Object {$_.RTSDate -match "2025"}' -ForegroundColor Cyan
Get-DellDeviceDetails -ModelLike "pro" | Where-Object {$_.RTSDate -match "2025"}
Write-Host ""
Read-Host
Write-Host "Get-DellDeviceDriverPack" -ForegroundColor Green
Get-DellDeviceDriverPack
Write-Host ""
Write-Host 'Get-DellDeviceDriverPack -SystemSKUNumber 0D4F -OSVer Windows11' -ForegroundColor Cyan
Get-DellDeviceDriverPack -SystemSKUNumber 0D4F -OSVer Windows11
Write-Host ""
Read-Host
Write-Host "Lets move on to BIOS Updates" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DellBIOSUpdates" -ForegroundColor Green
Get-DellBIOSUpdates
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -Check -Verbose' -ForegroundColor Cyan
Get-DellBIOSUpdates -Check -Verbose
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -DownloadPath c:\drivers' -ForegroundColor Cyan
Get-DellBIOSUpdates -DownloadPath c:\drivers
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -Flash' -ForegroundColor Cyan
Get-DellBIOSUpdates -Flash
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -SystemSKUNumber 066B' -ForegroundColor Cyan
Get-DellBIOSUpdates -SystemSKUNumber 066B
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -SystemSKUNumber 066B -Latest' -ForegroundColor Cyan
Get-DellBIOSUpdates -SystemSKUNumber 066B -Latest
Read-Host
Write-Host "Lets move on to Dell Command Update" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DCUAppUpdates -Latest" -ForegroundColor Green
Get-DCUAppUpdates -Latest
Write-Host ""
Read-Host
Write-Host 'Get-DCUAppUpdates -Install' -ForegroundColor Cyan
Get-DCUAppUpdates -Install
Write-Host ""
Read-Host
Write-Host "Get-DCUVersion" -ForegroundColor Green
Get-DCUVersion
Write-Host ""
Read-Host
Write-Host "Get-DCUInstallDetails" -ForegroundColor Green
Get-DCUInstallDetails
Write-Host ""
Read-Host
Write-Host "Manual Demo of Set-DCUSettings" -ForegroundColor Magenta
Write-Host "Then Launch DCU and show the settings" -ForegroundColor Cyan
Write-Host "Manual Demo of Invoke-DCU" -ForegroundColor Magenta