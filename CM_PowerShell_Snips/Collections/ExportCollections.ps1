# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

$CollectionExportPath = "\\src\src\CollectionExports"
$LimitingCollectionFilePath = "$CollectionExportPath\LimitingCollections"
Write-Host "Getting Collections .... This can take awhile..." -ForegroundColor Green
$Collections = Get-CMCollection
$LimitingCols = $Collections.LimitToCollectionID | Select-Object -Unique

Set-Location -Path $env:SystemDrive
Write-Host "Starting to Backup Collections" -ForegroundColor Green

New-Item -Path $LimitingCollectionFilePath -ItemType Directory -Force | Out-Null
foreach ($LimitingCol in $LimitingCols | Where-Object {$_ -ne ""}){
    Set-Location "$($SiteCode):\"
    $WorkingLimitingCol = Get-CMCollection -Id $LimitingCol
    if ($WorkingLimitingCol){
        $WorkingLimitingColName = ($WorkingLimitingCol.Name).replace("`'","").replace("`/","")
        Write-Host "Limiting Collection: $WorkingLimitingColName" -ForegroundColor Magenta
        Export-CMCollection -InputObject $WorkingLimitingCol -ExportFilePath "$LimitingCollectionFilePath\$WorkingLimitingColName).mof" -Force
        Set-Location -Path $env:SystemDrive
        New-Item -Path "$CollectionExportPath\$WorkingLimitingColName" -ItemType Directory -Force | Out-Null
        $LimitedCols = $Collections | Where-Object {$_.LimitToCollectionName -eq $($WorkingLimitingCol.Name)}
        Set-Location "$($SiteCode):\"
        foreach ($LimitedCol in $LimitedCols){
            $WorkingLimitedCol = Get-CMCollection -Id $LimitedCol.CollectionID
            $WorkingLimitedColName = ($WorkingLimitedCol.Name).replace("`'","").replace("`/","")
            Write-Host "  SubCollection: $WorkingLimitedColName" -ForegroundColor Cyan
            Export-CMCollection -InputObject $WorkingLimitedCol -ExportFilePath "$CollectionExportPath\$WorkingLimitingColName\$WorkingLimitedColName.mof" -Force
        }
    }
}
