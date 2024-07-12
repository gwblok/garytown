#Functions for ConfigMgr Endpoints

#HP CMSL WinPE replacement
Write-Host -ForegroundColor Cyan " ** Custom Functions for ConfigMgr Endpoints **"
Write-Host -ForegroundColor Green "[+] Function Get-CCMDTSJobsActive"
Write-Host -ForegroundColor Green "[+] Function Get-CCMDTSJobs"

Write-Host -ForegroundColor Cyan " ** Task Sequences **"
Write-Host -ForegroundColor Green "[+] Function Get-TSInfo "
Write-Host -ForegroundColor Green "[+] Function Start-TaskSequence"
Write-Host -ForegroundColor Green "[+] Function Get-TaskSequenceInfo "
Write-Host -ForegroundColor Green "[+] Function Get-TaskSequenceExecutionRequest"
Write-Host -ForegroundColor Green "[+] Function Reset-TaskSequence "
Write-Host -ForegroundColor Green "[+] Function Get-TSExecutionHistoryStatus "
Write-Host -ForegroundColor Green "[+] Function Get-TSExecutionHistoryStartTime "
Write-Host -ForegroundColor Green "[+] Function Set-TSExecutionHistory "
Write-Host -ForegroundColor Green "[+] Function Remove-TSExecutionHistory "
Write-Host -ForegroundColor Green "[+] Function Get-TaskSequenceReferenceInfo "

Write-Host -ForegroundColor Cyan " ** CM Content Functions **"
Write-Host -ForegroundColor Green "[+] Function Get-CMPackages "
Write-Host -ForegroundColor Green "[+] Function Start-PackageCommandLine  "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCacheInfo "
Write-Host -ForegroundColor Green "[+] Function Remove-CCMCacheItem "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCacheSizeInfo "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCachePackages "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCachePackageInfo "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCacheUpgradeMediaPackageInfo "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCacheSoftwareUpdates "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCacheApps "
Write-Host -ForegroundColor Green "[+] Function Get-BITSThrottlingPolicy "
Write-Host -ForegroundColor Green "[+] Function Set-BITSMaintenancePolicy "
Write-Host -ForegroundColor Green "[+] Function Get-CCMCachePackages "

Write-Host -ForegroundColor Cyan " ** CM Other Functions **"
Write-Host -ForegroundColor Green "[+] Function Set-LogPropertiesBitsLogMaxSize "
Write-Host -ForegroundColor Green "[+] Function Get-CMClientLogging "
Write-Host -ForegroundColor Green "[+] Function Set-CMClientLogging "
Write-Host -ForegroundColor Green "[+] Function Test-PendingReboot "
Write-Host -ForegroundColor Green "[+] Function Get-SetupCommandLine "
Write-Host -ForegroundColor Green "[+] Function Get-WMIRepo "

Write-Host -ForegroundColor Cyan " ** CM Baselines **"
Write-Host -ForegroundColor Green "[+] Function Get-Baselines "
Write-Host -ForegroundColor Green "[+] Function Invoke-Baseline"

Write-Host -ForegroundColor Cyan " ** CM Evals **"
Write-Host -ForegroundColor Green "[+] Function Invoke-CMClientMachinePolicy "
Write-Host -ForegroundColor Green "[+] Function Invoke-CMClientHWInv "
Write-Host -ForegroundColor Green "[+] Function Invoke-CMClientHWInvFull "


iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/CM_PowerShell_Snips/CM_Functions.ps1)
