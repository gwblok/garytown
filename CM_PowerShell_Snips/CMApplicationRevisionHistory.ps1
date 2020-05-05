########################################################################################################################
#Finds all Apps with "Microsoft Office 365" in the name, and removes all of teh revision history (besides the latest)
$OfficeApps = Get-CMApplication | Where-Object {$_.LocalizedDisplayName -match "Microsoft Office 365"}

foreach ($OfficeApp in $OfficeApps)
    {
    Get-CMApplicationRevisionHistory -InputObject $OfficeApp | Where-Object {$_.IsLatest -eq $false} | Remove-CMApplicationRevisionHistory -Force
    }
    
########################################################################################################################

