# Get all Networks in Stifler 2.10 
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks"
$Networks.count
$Networks | Export-Csv -Path C:\Temp\210Networks.csv -NoTypeInformation

# Get networks grouped by subnet (to find duplicates)
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks"
$GroupedByNetworkID = $Networks | Group-Object NetworkId | where-object { $_.Count -gt 1 } | Sort-Object Count -Descending
$GroupedByNetworkID.Count

foreach ($item in $GroupedByNetworkID) {
    $NetworkId = $item.Name

    $Networks = @(Get-WmiObject -namespace root\StifleR -Query "Select * from Networks where NetworkId = '$NetworkId'")
    foreach ($Network in $Networks)
    {
        $Nid = $Network.id
        $Data = Invoke-WmiMethod  -Path $Network.__PATH -Name GetDiscoveryData
        #$Data.ReturnValue | ConvertFrom-Json | Out-File C:\Temp\$($NetworkId)_NetworkConnectionData.txt
        $Data.ReturnValue | Out-File C:\Temp\$($NetworkId)_$($Nid)_NetworkConnectionData.json
        #break
    }
    #break
}


# Get network based on GatewayMAC
$GatewayMAC = "80-2D-BF-C6-56-F3"
Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where GatewayMAC = '$GatewayMAC'"

$Networks | Select -First 1 | Select NetworkId, Clients, GatewayMAC

# Find 32-bit Single-Computer VPN networks
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where SubnetMask = '255.255.255.255'"
$Networks.count

# Find networks for specific network group
$NetGrpId = "4bb1248e-f7bd-40c7-af04-e4f352fba2e8"
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where NetworkGroupId = '$NetGrpId'"
$Networks | Select NetworkId, Clients, GatewayMAC | Sort-Object GatewayMAC

# Find networks with GatewayMac
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where not GatewayMAC = ''"
$Networks.count

# Find networks without GatewayMac
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where GatewayMAC = ''"
$Networks.count

$Networks | Select NetworkId, GatewayMac




# Get a specifc network
$Networks = Get-CimInstance -Namespace root\stifler -Query "Select * From Networks where NetworkId = '162.141.20.0'"
$Networks.count
