
<#
#Add Info about PRevious Version 

$RefFolderRoot = "D:\HPIA-ReferenceFiles"
$RefFolderPrevious = (Get-ChildItem -Path $RefFolderRoot -Filter Reference* | Sort-Object -Descending) | Select-Object -First 2 | Select-Object -Last 1
$RefFolderLatest = (Get-ChildItem -Path $RefFolderRoot -Filter Reference* | Sort-Object -Descending) | Select-Object -First 1
$RefFilesLatest = Get-ChildItem -Path $RefFolderLatest.FullName | Where-Object {$_.Name -match "xml"}

#Build Change Log Folder:
$PreviousDate = $($RefFolderPrevious.name).Split("-") | Select-Object -Last 1
$LatestDate = $($RefFolderLatest.name).Split("-") | Select-Object -Last 1
#>

$TotalMachines = Get-HPDeviceDetails -Like *
$Platforms = $TotalMachines.SystemID | Select-Object -Unique

$OSTable = @(
@{ OS = 'win10'; OSVer = '21H2'}
@{ OS = 'win10'; OSVer = '22H2'}
@{ OS = 'win11'; OSVer = '21H2'}
@{ OS = 'win11'; OSVer = '22H2'}
)


#region functions
Function Get-CVEListFromCVA {
    [CmdletBinding()] param( $pCVAEnhancementsSection, $pPrivateFixes )

    $gc_CVEList = @()
    if ( $null -ne $pCVAEnhancementsSection ) {
        foreach ( $iLine in $pCVAEnhancementsSection ) {    # check every line under [US.Enhacemenents] for CVE
            $iLine = ($iLine -split ',' ).replace('.','').Trim().split(' ') -match "(CVE-[1-2][0-9]{3}-[0-9]{3,5})"
            $gc_CVEList += $iLine
        } # foreach ( $iLine in $pCVAEnhancementsSection )
    } # if ( $null -ne $pCVAEnhancementsSection )

    if ( $null -ne $pPrivateFixes ) {
        foreach ( $iLine in $pPrivateFixes ) {    # check every line under [US.Enhacemenents] for CVE
            $iLine = ($iLine -split ',' ).replace('.','').Trim().split(' ') -match "(CVE-[1-2][0-9]{3}-[0-9]{3,5})"
            $gc_CVEList += $iLine
        } # foreach ( $iLine in $pPrivateFixes )
    } # if ( $null -ne $pPrivateFixes )

    return $gc_CVEList  # list of CVEs found listed in CVA file or $null
} # Function Get_CVEListFromCVA


#endregion

<#
$SPListArray = @()

foreach ($RefFile in $RefFilesLatest)
    {
    $Ref1 = $null
    $Ref2 = $null
    $NewDriverArrayList = $null
    $RemovedDriverArrayList = $null
    $NewDriverUpdates = $null
    $RemovedDriverUpdates = $null
    #Latest Reference File XML
    [XML]$Ref = Get-Content -Path $RefFile.FullName -Raw #Newer Version of Ref File
    $UpdateInfo = $Ref.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -notmatch "Diagnostic" -and $_.Category -notmatch "Manageability"}
    $SPListArray += $UpdateInfo
}

#>
$SPListArrayCombo = @()
foreach ($Platform in $Platforms){
    foreach ($OS in $OSTable.OS | Select-Object -Unique){
        foreach ($OSVer in ($OSTable | Where-Object {$_.OS -eq $OS}).osver){
	        Write-Host "-- $Platform | $OS | $OSVer --" -ForegroundColor Cyan

            $SPList = Get-SoftpaqList -Platform $Platform -OS $OS -OSVer $OSVer -ErrorAction SilentlyContinue
            $SPListArrayCombo += $SPList
        }
    }
}


#Orignal Way
#$SPListArrayUnique = $SPListArray | Group-Object -Property 'id' | %{$_.Group[0]}

#Faster Way
$SPListArrayUnique = @{}
foreach($item in $SPListArrayCombo){if(!$SPListArrayUnique.ContainsKey($item.id)){$SPListArrayUnique.Add($item.id,$item)}}

$SP = $SPListArrayUnique.Values | Where-Object {$_.id -eq "sp148055"}

$SPListArrayUniqueValues = $SPListArrayUnique.Values| Where-Object {$_.Category -notmatch "Diagnostic" -and $_.Category -notmatch "Manageability"}

$SoftPaqInventoryArray = @()
foreach ($SP in $SPListArrayUniqueValues){
    
    Write-Host $SP.id
    $Platform = $null
    $CVE = $null
    $Description = $Null
    try {
        $SPMetaData = Get-SoftpaqMetadata -Number $SP.Id -ErrorAction SilentlyContinue
    
        #Gather Supported Platform Info
        $Platform = ($SPMetaData.'System Information'.Values | Where-Object {$_ -match "0x"}).replace("0x","")
        #[System.Collections.ArrayList]$Platforms = $Platform

        #Gather SoftPaq
        $CVE = Get-CVEListFromCVA $SPMetaData.'US.Enhancements'._body $SPMetaData.'Private_Fixes'._body
        #$CVEs = $CVE
        #if ($CVE.Count -gt 1){[System.Collections.ArrayList]$CVEs = $CVE}
        #else {$CVEs = $CVE}

        [string]$Description = ($SPMetaData.'US.Software Description')._body
    }
    catch {}
    #Other SoftPaq Info
    $ReleaseNotes = $SP.ReleaseNotes
    $Download = $SP.Url
    $ReleaseDate = $SP.ReleaseDate
    
    $Name = $SP.Name
    $Category = $SP.Category
    
    $SofPaqInventory = New-Object -TypeName PSObject
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "Name" -Value $Name -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "SoftPaqId" -Value $SP.id -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "Platform" -Value $Platform -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "CVEs" -Value $CVE -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value $ReleaseDate -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "Category" -Value $Category -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "ReleaseNotes" -Value "$ReleaseNotes" -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "Download" -Value "$Download" -Force	
    $SofPaqInventory | Add-Member -MemberType NoteProperty -Name "Description" -Value $Description -Force
    
    $SoftPaqInventoryArray += $SofPaqInventory 
}

$CollectHPSoftpaqInventory = $true 
$HPSoftPaqLogName = "HPSoftPaqInventory"

if ($CollectHPSoftpaqInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$HPSoftPaqLogName = $SoftPaqInventoryArray}
}
