#GARYTOWN - 2019.12.19 - @GWBLOK

#Connect to Cache
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'
$CMCacheObjects = $CMObject.GetCacheInfo()
$CacheUsedStart = $CMCacheObjects.TotalSize - $CMCacheObjects.FreeSize
$CacheTotalSizeStart = $CMCacheObjects.TotalSize
$CMCacheObjectsElements = $CMCacheObjects.GetCacheElements()
$CacheCountStart = $CMCacheObjectsElements.Count
if ($CMCacheObjects.TotalSize -lt 25600)
    {
    $CMCacheObjects.TotalSize = 25600
    Write-Output "Change size was $CacheTotalSizeStart, now $($CMCacheObjects.TotalSize)"
    }

#Get Packages with more than one instance
$Packages = $CMCacheObjects.GetCacheElements() | Group-Object -Property ContentID | ? {$_.count -gt 1}
if ($Packages.Count -ge 1)
    {
    Write-Output "$($Packages.Count) Packages with Duplicates... Removing..."
    #Go through the Duplicate Package and do magic.
    ForEach ($Package in $Packages) 
        {
        $PackageID = $Package.Name
        $PackageCount = ($CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"}).Count
        #Write-Host "Package: $PackageID has $PackageCount instances" -ForegroundColor Green
        $DuplicateContent = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"} 
        $ContentVersion = $DuplicateContent.ContentVersion | Sort-Object
        $HighestContentID = $ContentVersion | measure -Maximum
        $NewestContent = $DuplicateContent | Where-Object {$_.ContentVersion -eq $HighestContentID.Maximum}
        #write-host "Most Updated Package for $PackageID = $($NewestContent.ContentVersion)" -ForegroundColor Green
    
        $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq $PackageID -and $_.ContentVersion -ne $NewestContent.ContentVersion } | ForEach-Object { 
            $CMCacheObjects.DeleteCacheElement($_.CacheElementID)
            #Write-Host "Deleted: Name: $($_.ContentID)  Version: $($_.ContentVersion)" -BackgroundColor Red
            }
        }    

    Write-Output "Removed Duplicate Packages"
    }


$SoftwareUpdatesCache = $CMCacheObjects.GetCacheElements() | Where-Object { $_.ContentID | Select-String -Pattern '^[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$' }
Write-Output ""
Write-Output "-----------------------------------"
Write-Output "Reporting Software Updates in Cache | Count: $(($SoftwareUpdatesCache.ReferenceCount).Count)"
Write-Output ""

foreach ($SoftwareUpdate in $SoftwareUpdatesCache)
    {
    $SoftwareUpdateInfo = Get-CimInstance -Namespace root/ccm/SoftwareUpdates/UpdatesStore -ClassName CCM_UpdateStatus -Filter "UniqueId = '$(($SoftwareUpdate).ContentId)'"
    Write-Output "Name: $($SoftwareUpdateInfo.Title)"
    Write-Output "Status: $($SoftwareUpdateInfo.Status)"
    Write-Output "Cache Location: $($SoftwareUpdate.Location)"
    Write-Output "Cache Size: $($SoftwareUpdate.ContentSize)"
    Write-Output "__"
    }

$PackagesCache = $CMCacheObjects.GetCacheElements() | Where-Object { $_.ContentID | Select-String -Pattern '^\w{8}$' }

Write-Output ""
Write-Output "-----------------------------------"
Write-Output "Reporting Packages in Cache | Count: $(($PackagesCache.ReferenceCount).Count)"
Write-Output ""

foreach ($Package in $PackagesCache)
    {
    $PackageInfo = Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_SoftwareDistribution -Filter "PKG_PackageID = '$(($Package).ContentId)'"
    if ($PackageInfo.PKG_Name -eq $null)
        {
        $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq $($Package.ContentId) } | ForEach-Object {$CMCacheObjects.DeleteCacheElement($_.CacheElementID)}
        }
    else
        {
        if ($PackageInfo.Count -ge 1){Write-Output "Name: $($PackageInfo[0].PKG_Name)"}
        else {Write-Output "Name: $($PackageInfo.PKG_Name)"}
        Write-Output "Package ID: $($Package.ContentId)"
        Write-Output "Cache Location: $($Package.Location)"
        Write-Output "Cache Size: $($Package.ContentSize)"
        Write-Output "__"
        }
    }


#Applications
$AppCache = $CMCacheObjects.GetCacheElements() | Where-Object { $_.ContentID -match "Content" }
$CCM_AppDeliveryTypeSynclet = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet 


Write-Output ""
Write-Output "-----------------------------------"
Write-Output "Reporting Applications in Cache | Count: $(($AppCache.ReferenceCount).Count)"
Write-Output ""


foreach ($App in $AppCache)
    {
    #($CCM_AppDeliveryTypeSynclet | Where-Object { $_.InstallAction.Content.ContentId -eq $($App.ContentID)}).AppDeliveryTypeName
    Write-Output "Name: $(($CCM_AppDeliveryTypeSynclet | Where-Object { $_.InstallAction.Content.ContentId -eq $($App.ContentID)}).AppDeliveryTypeName)"
    Write-Output "Cache Location: $($App.Location)"
    Write-Output "Cache Size: $($App.ContentSize)"
    Write-Output "__"
    }



#Cache Used End
$CMCacheObjects = $CMObject.GetCacheInfo()
$CMCacheObjectsElements = $CMCacheObjects.GetCacheElements()
$CacheUsedEnd = $CMCacheObjects.TotalSize - $CMCacheObjects.FreeSize
$CacheCountEnd = $CMCacheObjectsElements.Count

if ($CacheCountStart -eq $CacheCountEnd){Write-Output "Total Cache Items: $CacheCountStart"}
Else{Write-Output "Total Cache Items at Start: $CacheCountStart, Cache Items Now: $CacheCountEnd"}

if ($CacheUsedStart -eq $CacheUsedEnd){Write-Output "Cache Size Used: $CacheUsedStart"}
Else {Write-Output "Cache Size Used at Start: $CacheUsedStart, Cache Used Now: $CacheUsedEnd"}

Write-Output "Cache Size Free: $($CMCacheObjects.FreeSize)"
