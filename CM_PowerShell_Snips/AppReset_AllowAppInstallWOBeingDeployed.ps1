<# Gary Blok @gwblok - Recast Software

Reset All Applications CheckBox: “Allow this application to be installed from the Install Application task sequence action without being deployed”
Unchecks the box, then Checks it again, then cleans up Application Revision History.

I had apps that had it checked when imported, yet the TS would fail: Task sequence run from software center fails error 0x80041002
execmgr log pointed to the applications I had associated with the TS.  I ran this script and then all was well.

#>
$CMApps = Get-CMApplication -Fast

Foreach ($CMApp in $CMApps)
    {
    Write-Host "Reset $($CMApp.LocalizedDisplayName)" -ForegroundColor Cyan
    Set-CMApplication -InputObject $CMApp -AutoInstall:$false 
    Set-CMApplication -InputObject $CMApp -AutoInstall:$true
    $CMAppRevisions = Get-CMApplicationRevisionHistory -InputObject $CMApp | Where-Object {$_.IsLatest -ne “True”}
    Foreach ($CMAppRevision in $CMAppRevisions) {
        Write-Output “Removing Revision $($CMAppRevision.CIVersion)”
        Remove-CMApplicationRevisionHistory -InputObject $CMAppRevision -Force
        }
    }
