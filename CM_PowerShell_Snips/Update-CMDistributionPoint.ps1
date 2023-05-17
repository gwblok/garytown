#Update Application's Deployment Type Content
$OfficeContentAppName = "Microsoft Office 365 - Content"
$OfficeContentAppDTName = "Office 365 ProPlus - Content"
Update-CMDistributionPoint -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
