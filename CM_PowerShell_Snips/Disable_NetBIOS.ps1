#Used in Task Sequence
$Adapters=(Get-WmiObject -ClassName win32_networkadapterconfiguration )
Write-Output "____________________________________________________________"
Write-Output "Disabling NetBIOS on Adapters:"
Write-Output ""
Foreach ($adapter in $adapters){
  Write-Output "Service: $($adapter.ServiceName) | Description: $($adapter.Description)"
  [VOID]$adapter.settcpipnetbios(2)}
Write-Output ""
Write-Output "Completed disabling NetBIOS"
Write-Output "____________________________________________________________" 
