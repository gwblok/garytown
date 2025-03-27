
$NetworkGroupsWithDirectRoute = Get-CimInstance -Namespace root\stifler -Query "Select * From NetworkGroups"

#$NetworkGroupCorrect = Get-CimInstance -Namespace root\stifler -Query "Select * From NetworkGroups Where Id = '2fe18477-2a35-41e9-83e2-9a1894c8e48b'"

$wrongNets = 0
$wrongNetsCliCount = 0

foreach ($NG in $NetworkGroupsWithDirectRoute)
{

    $clientcount = 0
    foreach ($Id in $NG.NetworksIds) 
    {
            
            $x = New-CimInstance -Namespace root\StifleR -ClassName Networks -Property @{ "id"="$Id" } -Key id -ClientOnly
            $network = Get-CimInstance -CimInstance $x
            $clientcount = $clientcount + $network.Clients
    }

    if($NG.Flags -band 64)
    {
        #DirectRoute  skipped as they will be deleted
        if($clientcount -ne 0)
        {
            Write-Host "Clients on Direct NG $($NG.id) with $($clientcount) changing it to NAT and adding externall addresses"
            #Find another network with the same networkid, or just delete them at let them come in again
            $ret = Invoke-CimMethod -Namespace root\StifleR -ClassName NetworkGroups -Name RemoveNetworkGroupUsingId -Arguments @{ NetworkGroupId = $NG.id ; Force = $true}

        }

       
        if($clientcount -eq 0)
        {
            #Write-Host "Deleting  $($NG.id) with $($clientcount)"
            #$ret = Invoke-CimMethod -Namespace root\StifleR -ClassName NetworkGroups -Name RemoveNetworkGroupUsingId -Arguments @{ NetworkGroupId = $NG.id ; Force = $true}
        }
    }
    else
    {
        if($NG.ExternalAddresses)
        {
            #Write-Host "Set on $($NG.id)"
        }
        else
        {

            $wrongNets++
            $wrongNetsCliCount = $wrongNetsCliCount + $clientcount

           Write-Host "Not Set on $($NG.id) with $($clientcount)"
           if($clientcount -eq 0)
           {
                #$ret = Invoke-CimMethod -Namespace root\StifleR -ClassName NetworkGroups -Name RemoveNetworkGroupUsingId -Arguments @{ NetworkGroupId = $NG.id ; Force = $true}

           }
        }
    }
}



$locations = Get-CimInstance -Namespace root\stifler -Query "Select * From Locations where NetworkGroupCount = 0"

foreach ($location in $locations)
{
    if($location.NetworkGroups)
    {

    }
    else
    {
        Write-Host "Deleteing $($location.id)"
        $ret = Invoke-CimMethod -Namespace root\StifleR -ClassName Locations -Name RemoveLocationUsingId -Arguments @{ LocationId = $location.id ; Force = $true}
    }
}




#Reset RoamingForever flag on Clients

$clients = Get-CimInstance -Namespace root\stifler -Query "Select * From Connections"
#$clients | Export-Csv -Path c:\temp\clients.csv
$roaming = 0;
$roamingForever = 0;

foreach ($client in $clients) 
{

        #if($client.Network -eq "172.16.184.0")
        #{
         #   $client.NetworkId
        
            
            if($client.ClientFlags -band 4294967296) 
            {
                $roamingForever++
                #Write-Host $roamingForever
                #$conn = [wmi]"\root\StifleR:Connections.ConnectionID='$($client.ConnectionId)'"
                #$conn.ResetRoamingForeverFlag();

                #Start-Sleep -Milliseconds 20
            
            }
        #}  
}