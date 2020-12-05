#@gwblok - Lookup KB and find the Deployment Package it is in.
#Run on CM Provider Server, or add -computername and your CM Provider

$SiteCode = "PS2"
$KB = "KB4586863"
$UPD = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_SoftwareUpdate
$PKG = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_SoftwareUpdatesPackage
$PKGC = Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -ClassName SMS_PackageToContent
$Update = $UPD | Where-Object {$_.LocalizedDisplayName -match $KB}
$UpdateInPackageID = (($PKGC | Where-Object {$_.ContentID -in $update.CI_ID}) | Select-Object -Property "PackageID" -Unique).PackageID
$UpdateInPackage = $PKG | Where-Object {$_.PackageID -eq $UpdateInPackageID}
$UpdateInPackage.Name
