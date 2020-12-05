#@gwblok - 2020.12.05
#Run on CM Provider Server, or add -computername and your CM Provider
#Put in a KB and get the Upgrade Deployment Package
#Only tested in my lab on a couple KBs
#Might need to tweak to work, honestly don't know.

$SiteCode = "PS2"
$KB = "KB4586863"
$UPD = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_SoftwareUpdate
$PKG = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_SoftwareUpdatesPackage
$PKGC = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_PackageToContent
$Update = $UPD | Where-Object {$_.LocalizedDisplayName -match $KB}
$UpdateInPackageID = (($PKGC | Where-Object {$_.ContentID -in $update.CI_ID}) | Select-Object -Property "PackageID" -Unique).PackageID
$UpdateInPackage = $PKG | Where-Object {$_.PackageID -eq $UpdateInPackageID}
Write-Output "Searched for $KB"
Write-Output " Found in Software Update Package: $($UpdateInPackage.Name)"
Write-Output "  $($UpdateInPackage.PkgSourcePath)"
