function Test-MeteredConnection {
#Note, has issues if you have HyperV installed with any other adapters besides the Default
$MeteredConnectionStatus = $null
[void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType = WindowsRuntime]
$cost = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile().GetConnectionCost()
$MeteredConnectionStatus = $cost.ApproachingDataLimit -or $cost.OverDataLimit -or $cost.Roaming -or $cost.BackgroundDataUsageRestricted -or ($cost.NetworkCostType -ne "Unrestricted")
if (!($MeteredConnectionStatus)){$MeteredConnectionStatus = $false}
return $MeteredConnectionStatus
}
