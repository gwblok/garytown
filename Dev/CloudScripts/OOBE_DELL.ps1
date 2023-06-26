$ScriptName = 'dell.garytown.com'
$ScriptVersion = '23.06.25.01'

#region Initialize
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$ScriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore


iex (irm functions.osdcloud.com)


$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
if ($Manufacturer -match "Dell"){
    $Manufacturer = "Dell"
    $DellEnterprise = Test-DCUSupport
}
else {
    Write-Host -ForegroundColor Red "[!] System is not supported a Dell, exiting in 5 seconds"
    Write-Host -ForegroundColor DarkGray " Manufacturer    = $Manufacturer"
    Write-Host -ForegroundColor DarkGray " Model           = $Model"
    Write-Host -ForegroundColor DarkGray " SystemSKUNumber = $SystemSKUNumber"
    Start-Sleep -Seconds 5
    exit
}

if ($DellEnterprise -eq $true) {
    Write-Host -ForegroundColor Green "Dell System Supports Dell Command Update"
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1')
}
else {
    Write-Host -ForegroundColor Red "[!] System is not supported by Dell Command Update, exiting in 5 seconds"
    Write-Host -ForegroundColor DarkGray " Manufacturer    = $Manufacturer"
    Write-Host -ForegroundColor DarkGray " Model           = $Model"
    Write-Host -ForegroundColor DarkGray " SystemSKUNumber = $SystemSKUNumber"
    Start-Sleep -Seconds 5
    exit
}


if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}



#region WinPE
if ($WindowsPhase -eq 'WinPE') {
    #Process OSDCloud startup and load Azure KeyVault dependencies
    osdcloud-StartWinPE -OSDCloud -KeyVault
    Write-Host -ForegroundColor Cyan "To start a new PowerShell session, type 'start powershell' and press enter"
    Write-Host -ForegroundColor Cyan "Start-OSDCloud, Start-OSDCloudGUI, or Start-OSDCloudAzure, can be run in the new PowerShell window"
    
    #Stop the startup Transcript.  OSDCloud will create its own
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Specialize
if ($WindowsPhase -eq 'Specialize') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region AuditMode
if ($WindowsPhase -eq 'AuditMode') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region OOBE
if ($WindowsPhase -eq 'OOBE') {
    #Load everything needed to run AutoPilot and Azure KeyVault
    Write-Host -ForegroundColor Green "[+] Running in"
    Write-Host -ForegroundColor Green "[+] Installing Dell Command Update"
    osdcloud-InstallDCU
    Write-Host -ForegroundColor Green "[+] Running Dell Command Update (Clean Image)"
    osdcloud-RunDCU -UpdateType CleanImage
    Write-Host -ForegroundColor Green "[+] Setting Dell Command Update to Auto Update"
    osdcloud-DCUAutoUpdate
    osdcloud-StartOOBE -Display -Language -DateTime -Autopilot -KeyVault
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Windows
if ($WindowsPhase -eq 'Windows') {
    #Load OSD and Azure stuff
    Write-Host -ForegroundColor Green "[+] Installing Dell Command Update"
    osdcloud-InstallDCU
    Write-Host -ForegroundColor Green "[+] Running Dell Command Update (Clean Image)"
    osdcloud-RunDCU -UpdateType CleanImage
    Write-Host -ForegroundColor Green "[+] Setting Dell Command Update to Auto Update"
    osdcloud-DCUAutoUpdate
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion
