

#This Script will be used to add computer names & IPs to the hosts file
$Servers2Add = @(
    @{SERVERNAME = "2PSR210" ; IPAddress = "192.168.20.25"}
    @{SERVERNAME = "2PSR210.2p.garytown.com" ; IPAddress = "192.168.20.25"}
    @{SERVERNAME = "2PStifleRMOM" ; IPAddress = "192.168.20.10"}
    @{SERVERNAME = "2PStifleRMOM.2p.garytown.com" ; IPAddress = "192.168.20.10"}
    @{SERVERNAME = "nas" ; IPAddress = "192.168.20.60"}
    @{SERVERNAME = "nas.2p.garytown.com" ; IPAddress = "192.168.20.60"}
)


#Approved Subnet Network Ranges for this script to run in.
#This is very simple and only works for 192.168.X.X networks, you'd have to modify it for other networks.
$SubnetNetworkRanges = (
    "192.168.1",
    "192.168.2",
    "192.168.3"
)
#Get IP Address and run if IP Address starts with 192.168.
$IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" }).IPAddress
write-output "IP Address found: $IPAddress"
if (-not $IPAddress) {
    Write-Output "The script will not run because the IP address does not start with 192.168."
    exit
}
else {
    $SubnetNetworkRanceFound = $false
    ForEach ($SubnetNetworkRange in $SubnetNetworkRanges) {
        if ([int]$IPAddress.Split(".")[2] -eq [int]"$($SubnetNetworkRange.Split('.')[2])") {
            Write-Output "IP address matches the subnet range: $SubnetNetworkRange"
            $SubnetNetworkRanceFound = $true
            break
        }
    }
    if ($SubnetNetworkRanceFound -eq $false) {
        Write-Output "The script will not run because the IP address does not match any of the specified subnet ranges."
        exit
    }   
}

function Test-HostFileEntry{
    param (
        [string]$ServerName,
        [string]$IPAddress
    )

    $HostFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostFileEntry = "$ServerName   $IPAddress"
    
    # Check if the entry already exists in the hosts file
    if (Select-String -Path $HostFilePath -Pattern $ServerName) {

        Write-Output "Entry for $ServerName already exists in the hosts file."
        return $true
    } else {
        Write-Output "Entry for $ServerName does not exist in the hosts file."
        return $false
    }
}

# Loop through each server and add the entry to the hosts file
foreach ($Server in $Servers2Add) {
    $ServerName = $Server.SERVERNAME
    $IPAddress = $Server.IPAddress
    if ((Test-HostFileEntry -ServerName $ServerName -IPAddress $IPAddress) -eq $false) {
        Write-Output "Does not exist, Triggering Remediation"
        exit 1
    }
}
