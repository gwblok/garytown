<# Gary Blok @gwblok GARYTOWN.COM
Sample of how to lookup Safe Guard Hold data based on the "database" I built and hosted in JSON here on GitHub

#>

$ID = '26062027'

$SafeGuardJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldDataBase.json'
$SafeGuardData = (Invoke-WebRequest -URI $SafeGuardJSONURL).content | ConvertFrom-Json

$SafeGuardData | Where-Object {$_.SafeguardID -eq $ID}
