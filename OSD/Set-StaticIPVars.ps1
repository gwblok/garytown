#This will grab the current IP Info from the adapter and make sure they are set on the variables.
$NetworkInfo = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.DHCPEnabled -eq $false}


#Setup TS Environment
try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch
{
	Write-Verbose "Not running in a task sequence."
}

$tsenv.value('OSDAdapter0IPAddressList') = $NetworkInfo.IPAddress[0]
$tsenv.value('OSDAdapter0SubnetMask') = $NetworkInfo.IPSubnet[0]
$tsenv.value('OSDAdapter0Gateways') = $NetworkInfo.DefaultIPGateway[0]
$tsenv.value('OSDAdapter0DNSServerList') = $NetworkInfo.DNSServerSearchOrder[0]
$tsenv.value('OSDAdapter0DNSSuffix') = $NetworkInfo.DNSDomainSuffixSearchOrder[0]

if ($NetworkInfo.DHCPEnabled -eq $false)
    {
    $tsenv.value('OSDAdapterCount') = 1
    $tsenv.value('OSDAdapter0EnableDHCP') = $false
    }
else {$tsenv.value('OSDAdapter0EnableDHCP') = $true}

    
