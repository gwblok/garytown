$ScriptName = 'dell.garytown.com'
$ScriptVersion = '24.06.10.01'

#region Initialize


$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
if ($Manufacturer -match "Dell"){
    $Manufacturer = "Dell"
    <#
    $DellEnterprise = Test-DCUSupport
    if ($DellEnterprise -eq $true) {
        Write-Host "Running $ScriptName - $ScriptVersion" -ForegroundColor Green
        Write-Host -ForegroundColor Green "Dell System Supports Dell Command Update"
        Write-Host -ForegroundColor Green " Enabling Dell Functions: https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1"
        Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/devicesdell.psm1')
    }
    if ($env:SystemDrive -eq 'X:') {
        $WindowsPhase = 'WinPE'
    }
    else {
        $WindowsPhase = 'Windows'
    }
    write-output "Running in Windows Phase: $WindowsPhase"

    #region Windows
    if ($WindowsPhase -eq 'Windows') {
        #Load OSD and Azure stuff
        Write-Host -ForegroundColor Green "[+] Installing Dell Command Update"
        osdcloud-InstallDCU
        Write-Host -ForegroundColor Green "[+] Running Dell Command Update Drivers"
        osdcloud-RunDCU -UpdateType driver
        Write-Host -ForegroundColor Green "[+] Running Dell Command Update BIOS"
        osdcloud-RunDCU -UpdateType bios
        Write-Host -ForegroundColor Green "[+] Setting Dell Command Update to Auto Update"
        osdcloud-DCUAutoUpdate
    }
    #endregion
    #>
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate/CMSL/Dell-CMSL.ps1')
    
}
