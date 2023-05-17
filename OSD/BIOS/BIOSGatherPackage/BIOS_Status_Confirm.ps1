#GWBLOK
#Future Updates to pull Registry path from TS Vars instead of hardcode

$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$RegistryPathWaaS = "HKLM:SOFTWARE\WaaS"
if ($TSENV.Value("CURRENTBIOSVERSION"))
    {
    $CurrentBIOSVer = $TSENV.Value("CURRENTBIOSVERSION")
    $TargetBIOSVersion = $TSENV.Value("TARGETBIOSVERSION")
    if (test-path $RegistryPathWaaS\BIOS\$TargetBIOSVersion)
        {
        $LastStatus = Get-ItemPropertyValue -path $RegistryPathWaaS -Name 'BIOSUpgradeStatus' -ErrorAction SilentlyContinue
        $LastUpgradeTo = Get-ItemPropertyValue -path $RegistryPathWaaS -Name 'BIOSUpgradeTo' -ErrorAction SilentlyContinue
        if ($CurrentBIOSVer -eq $LastUpgradeTo)
            {
            if ($LastStatus -ne "Success")
                {
                Write-Output "BIOS on Machine is Current, but last Status = failed... Updating Status to Success"
                New-ItemProperty -Path $RegistryPathWaaS -Name "BIOSUpgradeStatus" -Value "Success" -Force | Out-Null
                }
            }
        else
            {
            Write-Output "BIOS is not at Target BIOS Version - Considered FAILURE"
            }
        }
    }
