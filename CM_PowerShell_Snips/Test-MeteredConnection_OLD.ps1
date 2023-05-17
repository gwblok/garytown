function Test-MeteredConnection {
    # InterfaceType = https://docs.microsoft.com/en-us/uwp/api/windows.networking.connectivity.networkadapter.ianainterfacetype?view=winrt-22621

    $NetCards = Get-NetAdapter | Where-Object {$_.DriverDescription -notmatch "Virtual" -and $_.DriverDescription -notmatch "Blue" -and $_.DriverDescription -notmatch "Multiplexor" -and ($_.InterfaceType -eq 71 -or $_.InterfaceType -eq 6)}
    $ActiveNet = $NetCards | Where-Object {$_.Status -eq "Up"}
    $Null = $Value
    if ($ActiveNet.InterfaceType -eq 71){
        $RegPath = "HKLM:SOFTWARE\Microsoft\WlanSvc\Interfaces"
        $Profiles = get-item -Path "$RegPath\$($ActiveNet.InterfaceGuid)\Profiles"       
        foreach ($SubKey in $Profiles.GetSubKeyNames()){
            $HasConnected = get-item -Path "$RegPath\$($ActiveNet.InterfaceGuid)\Profiles\$SubKey\MetaData" | Where-Object {$_.Property -match "Has Connected"}
            if ($HasConnected){
                #Write-Output "$Subkey"
                $Value = ($HasConnected.GetValue("User Cost")  -join "")
            }
        }
        if ($value -ne ""){
            if ($Value -eq 20002000){$MeteredConnection = $true}
            else {$MeteredConnection = $false}
        }
        else
            {
            $RegPath = "HKLM:SOFTWARE\Microsoft\DusmSvc\Profiles"
            $Profiles = get-item -Path "$RegPath"  
            foreach ($SubKey in $Profiles.GetSubKeyNames()){
                $UserCostChild = Get-ChildItem -Path $RegPath\$SubKey | Where-Object {$_.Property -match "UserCost"}
                $UserCost = get-item $UserCostChild.PSPath
                $Value = $UserCost.GetValue('UserCost')
            }
            if ($value -ne "" -or $value -eq 0){
                if ($Value -eq 2){$MeteredConnection = $true}
                else {$MeteredConnection = $false}
            }
            else
                {
                $MeteredConnection = "unknown"
            }

        }
    }
    elseif ($ActiveNet.InterfaceType -eq 6){
        $RegPath = "HKLM:SOFTWARE\Microsoft\DusmSvc\Profiles"
        $Profiles = get-item -Path "$RegPath"  
        foreach ($SubKey in $Profiles.GetSubKeyNames()){
        $UserCostChild = Get-ChildItem -Path $RegPath\$SubKey | Where-Object {$_.Property -match "UserCost"}
        $UserCost = get-item $UserCostChild.PSPath
        $Value = $UserCost.GetValue('UserCost')
        }
        if ($value -ne "" -or $value -eq 0){
            if ($Value -eq 2){$MeteredConnection = $true}
            else {$MeteredConnection = $false}
            }
        else
            {
            $MeteredConnection = "unknown"
            }
    }

return $MeteredConnection
}
