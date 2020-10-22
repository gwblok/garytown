Function Get-TaskSequenceInfo {
 $TSInfo = Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PRG_DependentPolicy='False'"
    if ($TSInfo -ne $null)
        {
        write-host "Available Task Sequences:" -ForegroundColor Gray
        foreach ($TS in $TSInfo)
            {
            write-host " $($TS.PKG_Name) | PackageID: $($TS.PKG_PackageID) | DeployID: $($TS.ADV_AdvertisementID)" -ForegroundColor cyan
            $Collection = $DeploymentTable | Where-Object {$_.DID -eq $($TS.ADV_AdvertisementID)}
            if ($Collection){Write-Host "  Deployment Collection: $($Collection.DIDName)" -ForegroundColor Magenta}
            $ExHistory = Get-TSExecutionHistory -TSPackageID $TS.PKG_PackageID
            if ($ExHistory -eq "Success"){write-host "   Execution History: $ExHistory" -ForegroundColor Green}
            elseif ($ExHistory -eq "Failure"){write-host "   Execution History: $ExHistory" -ForegroundColor Red}
            else {write-host "   Execution History: $ExHistory" -ForegroundColor yellow}
            }
        }
}
