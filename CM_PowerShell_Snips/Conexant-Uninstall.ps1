<#https://docs.microsoft.com/en-us/windows/release-health/resolved-issues-windows-10-20h2#417msgdesc
@GWBLOK - GARYTOWN.COM

This script looks for Conexant ISST Audio drivers, then checks C:\windows\system32\UCI64A231.dll & UCI64A96.dll
If the file version matches or is older than the "Bad Version" According the MS Doc, we force uninstall the Audio Driver before upgrade, which then gets reinstalled during the upgrade process using the supplied Audio Drivers.

#>

[Version]$BadVersion = "7.231.3.0"
$InstalledDrivers = Get-WmiObject Win32_PnpSignedDriver
$CHDRT64ISST = $InstalledDrivers | Where-Object {$_.DriverName -match "CHDRT64ISST.sys"}
$Compliance = "Compliant"

Write-Output "--------------------------------"
Write-Output "Conexant ISST Audio Driver Check"

if ($CHDRT64ISST)
    {
    if (Test-Path "C:\windows\system32\UCI64A231.dll")
        {
        $UCI64A231 = get-item "C:\windows\system32\UCI64A231.dll"
        [Version]$UCI64A231Version = $UCI64A231.VersionInfo.FileVersion
        if ($UCI64A231Version -le $BadVersion)
            {
            $Compliance = "Non-Compliant"
            Write-Output "Conexant ISST Audio Driver Non-Compliant"
            Write-Output "File Version:$UCI64A231Version, Needs to be Higher than $BadVersion" 
            $UCI64A231 | select *
            }
        }
    if (Test-Path "C:\windows\system32\UCI64A96.dll")
        {
        $UCI64A96 = get-item "C:\windows\system32\UCI64A96.dll"
        [Version]$UCI64A96Version = $UCI64A96.VersionInfo.FileVersion
        if ($UCI64A96Version -le $BadVersion)
            {
            $Compliance = "Non-Compliant"
            Write-Output "Conexant ISST Audio Driver Non-Compliant"
            Write-Output "File Version:$UCI64A96Version, Needs to be Higher than $BadVersion" 
            $UCI64A96 | select *
            }
        }
    if ($Compliance -eq "Non-Compliant")
        {
        Write-Output ""
        Write-Output ""
        Write-Output $CHDRT64ISST
        Write-Output ""
        Write-Output ""
        $InfName = $CHDRT64ISST.InfName
        $HardWareID = $CHDRT64ISST.HardWareID
        $CompatID = $CHDRT64ISST.CompatID
        $DriverVersion = $CHDRT64ISST.DriverVersion
        $Description = $CHDRT64ISST.Description

        Write-Output "!!!!!!--------------------!!!!!!"
        Write-Output "Driver is Non-Compliant"
        Write-Output "Triggering Uninstall via PNPUtil of$Description, INF: $InfName, Version: $DriverVersion "
        pnputil /delete-driver $InfName /uninstall /force
        Write-Output "PNPUtil Command Complete"
        }
    else
        {
        Write-Output "Driver Compliant, no Remediation Required before Upgrade"
        }   
    }
else
    {
    Write-Output "Conexant ISST Audio Driver Not Installed"
    }
Write-Output "--------------------------------"
