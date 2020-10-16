<# 
Gary Blok | GARYTOWN | @gwblok
Used for CI Discovery Script

Update $TSPackageID to the Package ID for the Task Sequence you want to ensure the packages are cached for.

This script will look up the task sequence references and check the cache for the referenced packages
If any packages that are referenced in the TS are NOT in the ccmcache, script will write out "Non-Compliant" with list of Packages
Only if all packages are in cache, will it write "Compliant"
#>
$TSPackageID = 'PS200081'



#$ItemID = 'MEM00A07'
$TSInfo = Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PKG_PackageID='$TSPackageID'" -ErrorAction SilentlyContinue
$ReferenceItems = $TSInfo.TS_References
$TSDatabase = @()
$CachedPackageDatabase = @()
$PackageDatabase = @()
$LogFile = "$env:TEMP\CM_ContentCompliance_$TSPackageID.log"


Function Get-TSInfo {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PKG_PackageID='$TSPackageID'" 
    }

Function Get-CCMCachePackageInfo {
    [cmdletbinding()]
    param ([string] $PackageID)
    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
    $CMCacheObjects = $CMObject.GetCacheInfo() 
    $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match $PackageID}
    }

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $TSPackageID,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

CMTraceLog -Message  "----------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "--- Starting Content Compliance for $($TSInfo.PKG_Name) | $TSPackageID ---" -Type 1 -LogFile $LogFile
foreach ($Item in $ReferenceItems)
    {
    $ItemID = (($Item.split(" ")[1]).split('"'))[1]
    #write-host "-------"
    if ($ItemID -notmatch "Application")
        {
        #$ItemID
        $CacheInfo = Get-CCMCachePackageInfo -PackageID $ItemID
        $TSItemInfo = (Get-TSInfo -TSPackageID $ItemID -ErrorAction SilentlyContinue).PKG_Name
        #if ($TSItemInfo.count -ge 1){$TSItemInfo = $TSItemInfo[0]}
        if ((!($TSItemInfo)) -and (!($CacheInfo)))
            {
            #Write-Host $ItemID
            $PackageDatabase += $ItemID
            }
        if ($TSItemInfo){$TSDatabase += $TSItemInfo}
        if ($CacheInfo)
            {
            if ($CacheInfo.count -gt 1){$CacheInfo = $CacheInfo[-1]}
            $CachedPackageDatabaseObject = New-Object PSObject -Property @{
            ContentId = $CacheInfo.ContentID
            Location = $CacheInfo.Location
            ContentVersion = $CacheInfo.ContentVersion
            ContentSize = $CacheInfo.ContentSize
            }
            #Take the PS Object and append the Database Array    
            $CachedPackageDatabase += $CachedPackageDatabaseObject
            }
        }
    }

CMTraceLog -Message  "---------------------------------"  -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Referenced Packages in Cache"  -Type 1 -LogFile $LogFile
CMTraceLog -Message  ($CachedPackageDatabase | Out-String)  -Type 1 -LogFile $LogFile

if ($PackageDatabase -ne $null)
    {
    CMTraceLog -Message  "Summary: Non-Compliant, Missing Packages" -Type 2 -LogFile $LogFile
    CMTraceLog -Message   ($PackageDatabase | Out-String) -Type 1 -LogFile $LogFile
    Write-Host "NonCompliant: $PackageDatabase"
    }
Else {
    Write-Host "Compliant"
    CMTraceLog -Message  "Summary: Compliant" -Type 1 -LogFile $LogFile
    }

CMTraceLog -Message  "--- Finished Content Compliance for $TSPackageID ---" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "----------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "" -Type 1 -LogFile $LogFile
