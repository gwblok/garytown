#Stuff to make available in a Task Sequence

Write-Host -ForegroundColor Cyan "Functions for ConfigMgr Task Sequences"
Write-Host -ForegroundColor Green "[+] Function Confirm-TSEnvironmentSetup"
Write-Host -ForegroundColor Green "[+] Function Confirm-TSProgressUISetup"
Write-Host -ForegroundColor Green "[+] Function Get-TSVariables"
Write-Host -ForegroundColor Green "[+] Function Get-TSValue"
Write-Host -ForegroundColor Green "[+] Function Get-TSAllValues"
Write-Host -ForegroundColor Green "[+] Function Set-TSVariable"
Write-Host -ForegroundColor Green "[+] Function Close-TSProgressDialog"
Write-Host -ForegroundColor Green "[+] Function Show-TSActionProgress"
Write-Host -ForegroundColor Green "[+] Function Show-TSProgress"
Write-Host -ForegroundColor Green "[+] Function Show-TSErrorDialog"
Write-Host -ForegroundColor Green "[+] Function Show-TSMessage"
Write-Host -ForegroundColor Green "[+] Function Show-TSRebootDialog"
Write-Host -ForegroundColor Green "[+] Function Show-TSSwapMediaDialog"

iex (irm 'https://raw.githubusercontent.com/sombrerosheep/TaskSequenceModule/refs/heads/master/SCCM-TSEnvironment.psm1')

