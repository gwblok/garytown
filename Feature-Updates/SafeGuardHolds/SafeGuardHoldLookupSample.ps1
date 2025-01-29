<# Gary Blok @gwblok GARYTOWN.COM
Sample of how to lookup Safe Guard Hold data based on the "database" I built and hosted in JSON here on GitHub

#>

$ID = '26062027'

$SafeGuardJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldDataBase.json'
$SafeGuardData = (Invoke-WebRequest -URI $SafeGuardJSONURL).content | ConvertFrom-Json

$SafeGuardData | Where-Object {$_.SafeguardID -eq $ID}


#Previous Backup of the JSON file
$SafeGuardJSONBackupURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/backup/SafeGuardHoldDataBase.json'
$SafeGuardDataBackup = (Invoke-WebRequest -URI $SafeGuardJSONBackupURL).content | ConvertFrom-Json

$SafeGuardDataBackup | Where-Object {$_.SafeguardID -eq $ID}


#Grab Recent SafeGuards new for upgrading to 11 23H2
$23H2 = $SafeGuardData | Where-Object {$_.DEST_OS_GTE -match "23H2"}


# This is for the combined database, a lot of duplicate IDs, but the context of the ID can be slightly different.
# The change is typically in the "DEST_OS_GTE / LT" properties & EXE_ID
$SafeGuardCombinedJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldCombinedDataBase.json'
$SafeGuardCombinedData = (Invoke-WebRequest -URI $SafeGuardCombinedJSONURL).content | ConvertFrom-Json

$SafeGuardCombinedData | Where-Object {$_.SafeguardID -eq $ID}


