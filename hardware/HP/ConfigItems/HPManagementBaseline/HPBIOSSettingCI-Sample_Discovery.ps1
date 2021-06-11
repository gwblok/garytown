#Discovery Script
$SettingName = "Wake On LAN"
$DesiredValue = "Boot to Hard Drive"


#Don't Change below this line

Function Get-HPBIOSSettingWMI {
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	$SettingName
	)

$BIOS= Get-WmiObject -class hp_biossettinginterface -Namespace "root\hp\instrumentedbios"
$BIOSSetting = Get-CimInstance -class hp_biossetting -Namespace "root\hp\instrumentedbios"
$CurrentValue = ($BIOSSetting | ?{ $_.Name -eq $SettingName }).CurrentValue
if ($CurrentValue -ne $Null){return $CurrentValue}
else{Write-Output "BIOS Setting: $SettingName is NOT Available on this Hardware"}
}

$CurrentValue = Get-HPBIOSSettingWMI -SettingName $SettingName
if ($CurrentValue -eq $DesiredValue)
    {return "Compliant"}
elseif ($CurrentValue -match "NOT Available")
    {return "Compliant"}
else{return "Non-Compliant"}
