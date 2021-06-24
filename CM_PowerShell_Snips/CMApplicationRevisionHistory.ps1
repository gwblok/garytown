########################################################################################################################
#Finds all Apps with "Microsoft Office 365" in the name, and removes all of the revision history (besides the latest)
$OfficeApps = Get-CMApplication | Where-Object {$_.LocalizedDisplayName -match "Microsoft Office 365"}

foreach ($OfficeApp in $OfficeApps)
    {
    Get-CMApplicationRevisionHistory -InputObject $OfficeApp | Where-Object {$_.IsLatest -eq $false} | Remove-CMApplicationRevisionHistory -Force
    }
    


########################################################################################################################
#Finds all Apps with "Edge" in the name, and removes all of the revision history (besides the latest)
$Apps = Get-CMApplication | Where-Object {$_.LocalizedDisplayName -match "Edge"}

foreach ($App in $Apps)
    {
    $RevHistory = Get-CMApplicationRevisionHistory -InputObject $App
    Write-host "Starting App: $($App.LocalizedDisplayName) | Has $($RevHistory.count) revisions" -ForegroundColor Magenta
    Get-CMApplicationRevisionHistory -InputObject $App | Where-Object {$_.IsLatest -eq $false} | Remove-CMApplicationRevisionHistory -Force

    #Confirm
    $RevHistory = Get-CMApplicationRevisionHistory -InputObject $App
    Write-host " Starting App: $($App.LocalizedDisplayName) now has $($RevHistory.count) revision from $($RevHistory.DateLastModified)" -ForegroundColor Green
    write-host "-------------------------------------------------" -ForegroundColor Gray
    } 

