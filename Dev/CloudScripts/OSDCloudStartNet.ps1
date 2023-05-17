Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)

$Manufacturer = (Get-CimInstance -Class:Win32_ComputerSystem).Manufacturer
$Model = (Get-CimInstance -Class:Win32_ComputerSystem).Model
$HPTPM = $false
$HPBIOS = $false
$HPIADrivers = $false

if ($Manufacturer -match "HP" -or $Manufacturer -match "Hewlett-Packard"){
    $Manufacturer = "HP"
    if ($InternetConnection){
        $HPEnterprise = Test-HPIASupport
    }
}
if ($HPEnterprise){
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/deviceshp.psm1')
    osdcloud-InstallModuleHPCMSL
    $TPM = osdcloud-HPTPMDetermine
    $BIOS = osdcloud-HPBIOSDetermine
    $HPIADrivers = $true
    if ($TPM){
    write-host "HP Update TPM Firmware: $TPM - Requires Interaction" -ForegroundColor Yellow
        $HPTPM = $true
    }
    Else {
        $HPTPM = $false
    }

    if ($BIOS -eq $false){
        $CurrentVer = Get-HPBIOSVersion
        write-host "HP System Firmware already Current: $CurrentVer" -ForegroundColor Green
        $HPBIOS = $false
    }
    else
        {
        $LatestVer = (Get-HPBIOSUpdates -Latest).ver
        $CurrentVer = Get-HPBIOSVersion
        write-host "HP Update System Firmwware from $CurrentVer to $LatestVer" -ForegroundColor Yellow
        $HPBIOS = $true
    }
}


$Global:MyOSDCloud = [ordered]@{
        DevMode = [bool]$True
        WindowsDefenderUpdate = [bool]$True
        NetFx3 = [bool]$True
        SetTimeZone = [bool]$True
        HPIADrivers = [bool]$HPIADrivers
        Bitlocker = [bool]$True
        ClearDiskConfirm = [bool]$false
        OSDCloudUnattend = [bool]$True
        restart = [bool]$True
        HPTPMUpdate = [bool]$HPTPM
        HPBIOSUpdate = [bool]$HPBIOS
    }




Start-OSDCloud -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Pro -OSLicense Retail -OSLanguage en-us -ZTI
