Function Get-CCMCacheApps {
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet
$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}
$AppDatabase = @()
foreach ($App in $CCMCacheApps)
    {
    $Info = $CIModel | Where-Object {$_.InstallAction.Content.ContentId -eq $App.ContentId}
    $ContentID = $app.ContentId
    $Location = $app.Location
    $ContentVersion = $app.ContentVersion
    $ContentSize = $app.ContentSize
    $LastReferenceTime = $app.LastReferenceTime
    $AppDeliveryTypeId = $info.AppDeliveryTypeId
    $AppDTName = $info.AppDeliveryTypeName
    $AppDatabaseObject = New-Object PSObject -Property @{
        ContentId = $ContentID
        Location = $Location 
        ContentVersion = $ContentVersion
        ContentSize = $ContentSize
        LastReferenceTime = $LastReferenceTime
        AppDeliveryTypeId = $AppDeliveryTypeId
        AppDeliveryTypeName = $AppDTName
        }
        $AppDatabase += $AppDatabaseObject
    }
return $AppDatabase
}
