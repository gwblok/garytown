<# Gary Blok @gwblok GARYTOWN.COM
Sample of how to lookup Safe Guard Hold data based on the "database" I built and hosted in JSON here on GitHub

#>

$SafeGuardJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldDataBase.json'
$SafeGuardData = (Invoke-WebRequest -URI $SafeGuardJSONURL).content | ConvertFrom-Json

<# Single Lookup - Full details
$ID = '29991611'
$SafeGuardData | Where-Object {$_.SafeguardID -eq $ID}
#>

# Lookup several - Just ID & Name
$SafeGuardIDTable = @(
@{ ID = '41332279'}
@{ ID = '40667045'}
@{ ID = '25178825'}
@{ ID = '41332279'}
@{ ID = '30103339'}
@{ ID = '37820326'}
@{ ID = '29745406'}
@{ ID = '25178825'}
@{ ID = '35004082'}
@{ ID = '37395288'}
@{ ID = '26062027'}
@{ ID = '29991611'}
@{ ID = '30103339'}
@{ ID = '35004082'}
@{ ID = '25465644'}
@{ ID = '27227883'}
@{ ID = '29991611'}
@{ ID = '26490208'}
@{ ID = '41341219'}
@{ ID = '27227883'}
)



$Values = $SafeGuardIDTable.Values | Sort-Object

foreach ($ID in $Values){
    $WorkingSGD = $SafeGuardData | Where-Object {$_.SafeguardID -eq $ID}
    #$WorkingSGD | Select-Object -Property SafeguardId, AppName, Vendor, DEST_OS_GTE, DEST_OS_LT  
    #Write-Output "ID: $($WorkingSGD.SafeguardId) | Name: $($WorkingSGD.AppName) - $($WorkingSGD.VENDOR) | DesOS: >= $($WorkingSGD.DEST_OS_GTE) < $($WorkingSGD.DEST_OS_LT)"
    
    Write-Output "ID: $($WorkingSGD.SafeguardId) | Name: $($WorkingSGD.AppName) - $($WorkingSGD.VENDOR)"
    
    }

