#Snips to cleanup App Revision History, Works nice with a scheduled task... 
#If you know the specific names of apps, I recommend you replace Get-CMApplication | Where-Object ... with Get-CMApplication -Name, otherwise it can take awhile to dig through your apps.


#Simple - No write out:

########################################################################################################################
#Finds all Apps with "Microsoft Office 365" in the name, and removes all of the revision history (besides the latest)
$OfficeApps = Get-CMApplication | Where-Object {$_.LocalizedDisplayName -match "Microsoft Office 365"}

foreach ($OfficeApp in $OfficeApps)
    {
    Get-CMApplicationRevisionHistory -InputObject $OfficeApp | Where-Object {$_.IsLatest -eq $false} | Remove-CMApplicationRevisionHistory -Force
    }
    


#Slightly more Complicated, just adds some Write-host if you're watching the process.
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

