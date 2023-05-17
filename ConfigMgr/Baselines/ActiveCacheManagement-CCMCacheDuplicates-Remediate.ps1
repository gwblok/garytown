<#
Gary Blok | @gwblok | RecastSoftware.com


.SYNOPSIS
Checks for Duplicate Package IDs in CCMCache and Removes


#>


$OrgName = "Recast_IT"
[string]$Version = '2021.04.22'
$LogName = "CCMCacheChecker.log"
$LogDir = "$env:ProgramData\$OrgName\Logs"
$LogFile = "$LogDir\$LogName"
$ComponentText = "CCMCacheDuplicates"
$DetectionMode=$true
if (!(Test-Path -Path $LogDir)){New-Item -Path $LogDir -ItemType Directory -Force}


function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $ComponentText,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Logs\IForgotToNameTheLogVar.log"
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


#Delete Duplicate Instances of Package in CCMCache while keeping the most updated.

#Connect to CCM ComObject
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
        CMTraceLog -Message  "Deleted Name: $($_.ContentID)  Version: $($_.ContentVersion)" -Type 1 -LogFile $LogFile
        }
}  
