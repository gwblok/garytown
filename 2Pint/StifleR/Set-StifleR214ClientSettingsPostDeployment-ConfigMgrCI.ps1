#Variable Declaration
$Remediation = $true #Set to False on your Discovery / Detection


#Settings you want to check
$DesiredServerName = '214-StifleR.2p.garytown.com' #Replaces this information into the StiflerServers registry key
$DesiredVPNClient = 'WireGuard'  #Appends this information into the VPNStrings registry key


#Script Content:
$Compliance = $true
$StifleRRegPath = 'HKLM:\SOFTWARE\2Pint Software\StifleR\Client\SettingsOptions'
if (Test-Path -Path $StifleRRegPath){
    $StifleRSettings = Get-Item -Path $StifleRRegPath
    [STRING]$StifleRServerString = $StifleRSettings.GetValue('StiflerServers')
    [STRING]$StifleRVPNClientString = $StifleRSettings.GetValue('VPNStrings')
    if ($StifleRServerString -match $DesiredServerName){
        Write-Host -ForegroundColor Green "StifleR Server Name is already set to $DesiredServerName"
    }
    else {
        if ($Remediation){
            Write-Host -ForegroundColor Yellow "Changing StifleR Server Name from $StifleRServerString to [`"https://$($DesiredServerName):1414`"]"
            Set-ItemProperty -Path $StifleRRegPath -Name 'StiflerServers' -Value "[`"https://$($DesiredServerName):1414`"]" -force
        }
        else{
            Write-Host -ForegroundColor Red "Request Value: $DesiredServerName |  Current Value: $StifleRServerString"
            $Compliance = $false
            return $Compliance
        }
    }
    if ($StifleRVPNClientString -match $DesiredVPNClient){
        Write-Host -ForegroundColor Green "StifleR VPN Client is already set to $DesiredVPNClient"
    }
    else {
        if ($Remediation){
            $UpdatedString = $StifleRVPNClientString.Replace("]", ",`"$DesiredVPNClient`"]")
            Write-Host -ForegroundColor Yellow "Changing StifleR VPN Client from $StifleRVPNClientString to $UpdatedString"
            Set-ItemProperty -Path $StifleRRegPath -Name 'VPNStrings' -Value $UpdatedString -force
        }
        else{
            Write-Host -ForegroundColor Red "Request Value: $DesiredVPNClient |  Current Value: $StifleRVPNClientString"
            $Compliance = $false
            return $Compliance
        }
    }
}

return $Compliance
