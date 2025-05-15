$ScriptName = 'blacklotus.garytown.com'
$ScriptVersion = '25.5.15.1'
#Set-ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue

Write-Host -ForegroundColor Green "You are running: $ScriptName $ScriptVersion"
Write-host -ForegroundColor Cyan " Docs at: https://github.com/gwblok/garytown/tree/master/BlackLotusKB5025885"
#endregion



write-host -ForegroundColor DarkGray "========================================================="
write-host -ForegroundColor Cyan "Black Lotus Functions"

Write-Host -ForegroundColor Green "[+] Function Test-BlackLotusKB5025885Compliance (-Details)"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/BlackLotusKB5025885/Test-BlackLotusKB5025885Compliance.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-BlackLotusKB5025885Compliance"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/BlackLotusKB5025885/Invoke-BlackLotusKB5025885Compliance.ps1)

Write-Host -ForegroundColor Green "[+] Function Update-BootMgr2023"
function Update-BootMgr2023 {
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/BlackLotusKB5025885/Update-BootMgr2023.ps1)
}