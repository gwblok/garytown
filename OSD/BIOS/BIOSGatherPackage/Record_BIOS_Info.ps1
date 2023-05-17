Write-Output "----------------------------------------------------"
Write-Output "Starting Record BIOS Info to Registry Step"

$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment

#Grab Info about Current BIOS State
$BIOS = Get-WmiObject -Class 'Win32_Bios'


$UpgradeBIOSReturnCode = $TSENV.Value("UpgradeBIOSReturnCode")
Write-Output "BIOS Upgrade Step Exit code $UpgradeBIOSReturnCode"
$TargetBIOSVersion = $TSENV.Value("TARGETBIOSVERSION")
$TargetBIOSDate = $TSENV.Value("TARGETBIOSDATE")
Write-Output "TARGETBIOSVERSION = $TargetBIOSVersion | TARGETBIOSDATE = $TargetBIOSDate"
$RegistryPathWaaS = "HKLM:SOFTWARE\WaaS"
$RegistryPathBIOS = "HKLM:SOFTWARE\WaaS\BIOS"
if (!(Test-path -Path $RegistryPathWaaS)){New-Item -Path $RegistryPathWaaS | Out-Null}
if (!(Test-path -Path $RegistryPathBIOS)){New-Item -Path $RegistryPathBIOS | Out-Null}
if (!(Test-path -Path $RegistryPathBIOS\$TargetBIOSVersion)){New-Item -Path $RegistryPathBIOS\$TargetBIOSVersion | Out-Null}

$Reporting_CurrentBIOSVer = $TSENV.Value("CURRENTBIOSVERSION")
$Reporting_CurrentBIOSDate = $TSENV.Value("CURRENTBIOSDATE")
$Reporting_FinishFlashTime = Get-Date -f 's'

$TSENV.Value("Reporting_CurrentBIOSVer") = $Reporting_CurrentBIOSVer
$TSENV.Value("Reporting_CurrentBIOSVerRAW") = $($BIOS.SMBIOSBIOSVersion)
$TSENV.Value("Reporting_CurrentBIOSDate") = $Reporting_CurrentBIOSDate
$TSENV.Value('Reporting_FinishFlashTime') = $Reporting_FinishFlashTime

$Reporting_CurrentBIOSVerRAW = $TSENV.Value("Reporting_CurrentBIOSVerRAW")
$Reporting_DownlevelBIOSVer = $TSENV.Value("Reporting_DownlevelBIOSVer")
$Reporting_DownlevelBIOSVerRAW = $TSENV.Value("Reporting_DownlevelBIOSVerRAW")
$Reporting_DownlevelBIOSDate = $TSENV.Value("Reporting_DownlevelBIOSDate")
$Reporting_StartFlashTime = $TSENV.Value('Reporting_StartFlashTime')

write-output "Reporting_CurrentBIOSVer = $Reporting_CurrentBIOSVer "
write-output "Reporting_CurrentBIOSDate = $Reporting_CurrentBIOSDate"
write-output "Reporting_CurrentBIOSVerRAW = $Reporting_CurrentBIOSVerRAW"
write-output "Reporting_DownlevelBIOSVer = $Reporting_DownlevelBIOSVer"
write-output "Reporting_DownlevelBIOSVerRAW = $Reporting_DownlevelBIOSVerRAW"



#Write Information to Regsitry
if ($Reporting_DownlevelBIOSVerRAW -ne $Reporting_CurrentBIOSVerRAW) #BIOS Versions are different (The Upgrade succeeded and the BIOS is now newer)
    {
    Write-Output '$Reporting_DownlevelBIOSVerRAW -ne $Reporting_CurrentBIOSVerRAW'
    Write-Output "$Reporting_DownlevelBIOSVerRAW -ne $Reporting_CurrentBIOSVerRAW"
    Write-Output "BIOS Versions are different (The Upgrade succeeded and the BIOS is now newer)"
    if ($Reporting_DownlevelBIOSVer -ne $null -and $Reporting_DownlevelBIOSVer -ne "" -and $Reporting_CurrentBIOSVer -ne $null -and $Reporting_CurrentBIOSVer -ne "")
        {
        Write-output "--------------------------------------------"
        Write-output "Capturing Data to Registry For Reporting"
    
        #Write to Root (WaaS) - For Inventory
        Write-Output "Updating Registry: $RegistryPathWaaS"
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeFrom" -Value $Reporting_DownlevelBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeTo" -Value $Reporting_CurrentBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeDate" -Value $Reporting_FinishFlashTime -Force | Out-Null
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeStatus" -Value "Success" -Force | Out-Null

        #Write to SubKey for Troubleshooting - NOT Inventory 
        $RegUpdatePath = "$RegistryPathBIOS\$Reporting_CurrentBIOSVer"
        Write-Output "Updating Registry: $RegUpdatePath"
        if (!(Test-path -Path $RegUpdatePath)){New-Item -Path $RegUpdatePath}
        New-ItemProperty -Path $RegUpdatePath -Name "Downlevel" -Value $Reporting_DownlevelBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeTo" -Value $Reporting_CurrentBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeStartTime" -Value $Reporting_StartFlashTime -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeFinishTime" -Value $Reporting_FinishFlashTime -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "BIOSPackage" -Value $TSENV.Value("BIOSPACKAGE") -Force | Out-Null

        Write-output "Name: Downlevel          | Value: $Reporting_DownlevelBIOSVer"
        Write-output "Name: UpgradeTo          | Value: $Reporting_CurrentBIOSVer"
        Write-output "Name: UpgradeStartTime   | Value: $Reporting_StartFlashTime"
        Write-output "Name: UpgradeFinishTime  | Value: $Reporting_FinishFlashTime"

        Write-output "Complete Capturing BIOS Reporting Info"
        }
    }
else #If BIOS Versions still the same (Failure to update)
    {
    Write-Output '$Reporting_DownlevelBIOSVerRAW -eq $Reporting_CurrentBIOSVerRAW'
    Write-Output "$Reporting_DownlevelBIOSVerRAW -eq $Reporting_CurrentBIOSVerRAW"
    Write-Output "BIOS Versions are The Same (The Upgrade FAILED)"
    if ($TSENV.Value("FLASHBIOS") -eq "TRUE") #Just making sure it was supposed to change versions (Upgrade)
        {
        Write-output "---------------------------FAIL-------------------------"
        Write-output "BIOS Should of upgraded, but didn't, so that's not good."
        Write-output "---------------------------FAIL-------------------------"
        #Write to Root (WaaS) - For Inventory
        Write-Output "Updating Registry: $RegistryPathWaaS"
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeFrom" -Value $Reporting_DownlevelBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeTo" -Value $TargetBIOSVersion -Force | Out-Null
        New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeDate" -Value $Reporting_FinishFlashTime -Force | Out-Null
        if ($UpgradeBIOSReturnCode){
            New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeStatus" -Value "Failed Code: $UpgradeBIOSReturnCode" -Force | Out-Null
            }
        else
            {
            New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeStatus" -Value "Failed" -Force | Out-Null
            }

        #Write to SubKey for Troubleshooting - NOT Inventory
        $RegUpdatePath = "$RegistryPathBIOS\$TargetBIOSVersion"
        Write-Output "Updating Registry: $RegUpdatePath"
        if (!(Test-path -Path $RegUpdatePath)){New-Item -Path $RegUpdatePath | Out-Null}
        New-ItemProperty -Path $RegUpdatePath -Name "Downlevel" -Value $Reporting_DownlevelBIOSVer -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeTo" -Value $TargetBIOSVersion -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeStartTime" -Value $Reporting_StartFlashTime -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeFinishTime" -Value $Reporting_FinishFlashTime -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "UpgradeStatus" -Value "Failed" -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "BIOSPackage" -Value $TSENV.Value("BIOSPACKAGE") -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "FLASHBIN" -Value $TSENV.Value("FLASHBIN") -Force | Out-Null
        New-ItemProperty -Path $RegUpdatePath -Name "ExitCode" -Value $TSENV.Value("UpgradeBIOSReturnCode") -Force | Out-Null

        Write-output "Name: Downlevel          | Value: $Reporting_DownlevelBIOSVer"
        Write-output "Name: UpgradeTo          | Value: $TargetBIOSVersion"
        Write-output "Name: UpgradeStartTime   | Value: $Reporting_StartFlashTime"
        Write-output "Name: UpgradeFinishTime  | Value: $Reporting_FinishFlashTime"
        Write-output "Name: BIOSUpgradeStatus  | Value: Failed"
        Write-output "Name: BIOSPackage        | Value: $($TSENV.Value("BIOSPACKAGE"))"
        Write-output "Name: FLASHBIN           | Value: $($TSENV.Value("FLASHBIN"))"
        Write-output "Name: ExitCode           | Value: $($TSENV.Value("UpgradeBIOSReturnCode"))"
        }
    else #This situation shouldn't even be possible.
        {
        Write-output "BIOS Values the Same, Nothing to Capture"
        }
    }

