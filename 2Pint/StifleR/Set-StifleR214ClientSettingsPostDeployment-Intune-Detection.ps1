#Settings you want to check
$DesiredServerName = '214-StifleR.2p.garytown.com' #Replaces this information into the StiflerServers registry key
$DesiredVPNClient = 'WireGuard'  #Appends this information into the VPNStrings registry key


#Script Content:
$StifleRRegPath = 'HKLM:\SOFTWARE\2Pint Software\StifleR\Client\SettingsOptions'
if (Test-Path -Path $StifleRRegPath){
    $StifleRSettings = Get-Item -Path $StifleRRegPath
    [STRING]$StifleRServerString = $StifleRSettings.GetValue('StiflerServers')
    [STRING]$StifleRVPNClientString = $StifleRSettings.GetValue('VPNStrings')
    if ($StifleRServerString -match $DesiredServerName){
        Write-Host -ForegroundColor Green "StifleR Server Name is already set to $DesiredServerName"
    }
    else {
        Write-Host -ForegroundColor Red "Request Value: $DesiredServerName |  Current Value: $StifleRServerString"
        Exit 1
    }
    if ($StifleRVPNClientString -match $DesiredVPNClient){
        Write-Host -ForegroundColor Green "StifleR VPN Client is already set to $DesiredVPNClient"
    }
    else {
        Write-Host -ForegroundColor Red "Request Value: $DesiredVPNClient |  Current Value: $StifleRVPNClientString"
        Exit 1
    }
}
else {
    Write-Host -ForegroundColor Red "StifleR Registry Path not found: $StifleRRegPath"
}
