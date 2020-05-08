<# CM Commandlets in this example:
New-CMDetectionClauseFile
Get-CMDeploymentType
Set-CMScriptDeploymentType -AddDetectionClause
Set-CMScriptDeploymentType -RemoveDetectionClause
#>

#Create a File Detection Type
$CabName = "v629.cab"
$DetectionFilePath = "$O365Cache\Office\Data"
$DetectionTypeUpdate = New-CMDetectionClauseFile -FileName $CabName -Path $DetectionFilePath -Existence

#Add New Detection Method to AppDT
$OfficeContentAppName = "Microsoft Office 365 - Content"
$OfficeContentAppDTName = "Office 365 ProPlus - Content"
Get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeUpdate

#Remove Detection Method from App (This was hard)
#Requires you know the Logical Name of the App (Which the only way I could find was burried in XML)
#Get App Info after updating, then Remove the old Detection (Removes anything that doesn't match the new detection)
$CMDeploymentType = get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName
[XML]$AppDTXML = $CMDeploymentType.SDMPackageXML
[XML]$AppDTDXML = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.DetectAction.args.Arg[1].'#text'
$DetectionMethods = $AppDTDXML.EnhancedDetectionMethod.Settings.File
$LogicalName = ($DetectionMethods | Where-Object {$_.Filter -ne $CabName}).LogicalName
Get-CMDeploymentType -ApplicationName $OfficeContentAppName -DeploymentTypeName $OfficeContentAppDTName | Set-CMScriptDeploymentType -RemoveDetectionClause $LogicalName
