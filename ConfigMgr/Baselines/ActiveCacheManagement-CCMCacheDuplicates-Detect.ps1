<#
Gary Blok | @gwblok | RecastSoftware.com

.SYNOPSIS
Checks for Duplicate Package IDs in CCMCache, if found, sets Non-compliant

#>

$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'
$CMCacheObjects = $CMObject.GetCacheInfo()

#Get count of packages with more than one instance
$DuplicatePackageCount = ($CMCacheObjects.GetCacheElements() | Group-Object -Property ContentID | ? {$_.count -gt 1}).Count

if ($DuplicatePackageCount -ge 1) {
    Write-Host "Non-compliant"
    }
else {
    Write-Host "Compliant"
    }
