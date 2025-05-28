#Script to create networks in a Network Group in StifleR

$serverName = $env:COMPUTERNAME

$NGGuid1 = '97567112-f701-4480-9a20-317b1df2cef1'
$NGGuid2 = '85f8e19b-15e0-4916-8b5b-3ad1a78fa63f'

$start = 1
$end = 32

do{
    $args = @{
    NetworkGroupID = $NGGuid1;   # <== change to the correct Network Group ID you want to use
    NetworkID = "172.29.$($start).0";
    NetworkMask = "255.255.255.0";
    GatewayMAC = ""
    }
    $ret = Invoke-CimMethod -ComputerName $serverName -Namespace root\StifleR -ClassName Networks -MethodName AddNetwork -Arguments $args
    $start += 1

} until ($start -eq $end+1)