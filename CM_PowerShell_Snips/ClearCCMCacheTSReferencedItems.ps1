Function Remove-CCMCacheItem {
    [cmdletbinding()]
    param ([string] $ContentID)
    # Connect to resource manager COM object    
    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
    # Using GetCacheInfo method to return cache properties 
    $CMCacheObjects = $CMObject.GetCacheInfo() 
    # Delete Cache item 
    $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -in $ContentID} | ForEach-Object { 
        $CMCacheObjects.DeleteCacheElementEx($_.CacheElementID,$True)
        Write-Host "Deleted: Name: $($_.ContentID)  Version: $($_.ContentVersion)" -ForegroundColor Red
    }
}


#region clear out duplicates
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'
$CMCacheObjects = $CMObject.GetCacheInfo()

#Get Packages with more than one instance
$Packages = $CMCacheObjects.GetCacheElements() | Group-Object -Property ContentID | ? {$_.count -gt 1}

#Go through the Duplicate Package and do magic.
ForEach ($Package in $Packages) 
    {
    $PackageID = $Package.Name
    $PackageCount = ($CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"}).Count
    Write-Host "Package: $PackageID has $PackageCount instances" -ForegroundColor Green
    $DuplicateContent = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"} 
    $ContentVersion = $DuplicateContent.ContentVersion | Sort-Object
    $HighestContentID = $ContentVersion | measure -Maximum
    $NewestContent = $DuplicateContent | Where-Object {$_.ContentVersion -eq $HighestContentID.Maximum}
    write-host "Most Updated Package for $PackageID = $($NewestContent.ContentVersion)" -ForegroundColor Green
    
    $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq $PackageID -and $_.ContentVersion -ne $NewestContent.ContentVersion } | ForEach-Object { 
        $CMCacheObjects.DeleteCacheElement($_.CacheElementID)
        Write-Host "Deleted: Name: $($_.ContentID)  Version: $($_.ContentVersion)" -BackgroundColor Red
        }
}  

#endregion

$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment  
$ReferencePkgs = ($tsenv.Value('_SMSTSPkgReferenceList')).split(" ")

foreach ($ReferencePkg in $ReferencePkgs){
    if ($ReferencePkg -ne ""){
        Write-Host "Package $ReferencePkg" -ForegroundColor Green
        Remove-CCMCacheItem -ContentID $ReferencePkg
        Write-Host "----------------------"
    }
}
