#Gary Blok | GARYTOWN.COM | @GWBLOK
#Enable RDP Detect Script

<#
$TSKeyPath = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'

$RegValues = @(
@{Name = "fDenyTSConnections"; Value = 0}
#@{Name = "updateRDPStatus"; Value = 1}
)
#Test RPD Reg Values for Enabled
foreach ($Reg in $RegValues){
    $Reg.Name
    $TestValue = Get-ItemPropertyValue -Path $TSKeyPath -name $Reg.Name -ErrorAction SilentlyContinue
    if ($TestValue -ne $Reg.Value){
        Write-Output "exit 1"
    }
}
#>

#Test for Remote Connections Allowed
if ((Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\CIMV2\TerminalServices).AllowTSConnections -ne 1){
    exit 1
}


#Test NLA for Disabled
if ((Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").UserAuthenticationRequired -ne 0){
    exit 1
}
