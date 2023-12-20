#Used to verify Secure Platform & Sure Recover Setup.  
#Get settings direct from WMI, skipping HPCMSL requirement

$BIOSSettings = Get-CimInstance -ClassName hp_biossetting -Namespace "root\hp\instrumentedbios"

#region SPM
Write-Host "Secure Platform Info" -ForegroundColor Green
Write-Host ""
#Secure Platform Management Current State
Write-Host "Secure Platform Management Current State" -ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "Secure Platform Management Current State"}).Value
Write-Host ""

#Secure Platform Management Key Endorsement Key
Write-Host "Secure Platform Management Key Endorsement Key" -ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "Secure Platform Management Key Endorsement Key"}).Value
Write-Host ""

#Secure Platform Management Signing Key
Write-Host "Secure Platform Management Signing Key" -ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "Secure Platform Management Signing Key"}).Value
Write-Host ""


#endregion SPM



#region Sure Recover
Write-Host ""
Write-Host "Sure Recover Info" -ForegroundColor Green
Write-Host ""

#HP Sure Recover
Write-Host "Sure Recover Current State" -ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery"}).CurrentValue
Write-Host ""

#Agent
Write-Host "OS Recovery Agent URL"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Agent URL"}).Value
Write-Host ""

Write-Host "OS Recovery Agent Provisioning Version"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Agent Provisioning Version"}).Value
Write-Host ""

Write-Host "OS Recovery Agent Public Key"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Agent Public Key"}).Value
Write-Host ""

#OS Image
Write-Host "OS Recovery Image URL"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Image URL"}).Value
Write-Host ""

Write-Host "OS Recovery Image Provisioning Version"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Image Provisioning Version"}).Value
Write-Host ""

Write-Host "OS Recovery Image Public Key"-ForegroundColor Cyan
($BIOSSettings | Where-Object {$_.Name -eq "OS Recovery Image Public Key"}).Value
Write-Host ""

#endregion Sure Recover
