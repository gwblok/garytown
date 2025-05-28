<#Script to create networks in a predefined Network Group in StifleR
Things for you to change: 
- GUID(s) for Network Group(s)
- NetworkID in the Do loop (EX: 192.128.$start.0)

#>

#This assumes you're running this on the StifleR server and that you have the StifleR CIM classes available.
$serverName = $env:COMPUTERNAME

#GUIDs for the Network Groups you want to add networks to.
$NGGuid1 = 'fd1f1dc9-44be-44d5-ab7d-62710c816d60'
#$NGGuid2 = '17140f41-7d79-44a9-80f3-e05eba4841e8'

#Network range to create networks in the Network Group.
$start = 0  #Example: 192.128.$start.0
$end = 31 # Example: 192.128.$end.31

# Loop to create networks in the specified range. - Swap out the NetworkGroupID with the one you want to use.
do{
    $args = @{
    NetworkGroupID = $NGGuid1;   # <== change to the correct Network Group ID you want to use
    NetworkID = "192.128.$($start).0";
    NetworkMask = "255.255.255.0";
    GatewayMAC = ""
    }
    Write-Host -ForegroundColor Cyan "Creating Network: $($args.NetworkID) in Network Group: $($args.NetworkGroupID)"
    #Invoke the CIM method to add the network
    $ret = Invoke-CimMethod -ComputerName $serverName -Namespace root\StifleR -ClassName Networks -MethodName AddNetwork -Arguments $args
    $start += 1

} until ($start -eq $end+1)
Write-Host "Created networks in Network Group: $NGGuid1 from 192.128.$($start-$end-1).0 to 192.128.$end.0" -ForegroundColor Magenta