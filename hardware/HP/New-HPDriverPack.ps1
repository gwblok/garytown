<#
    Script to create a DriverPack
    by Dan Felman/HP - 2/18/2022
    Version 
        (1.01.01 Shows drivers with UWP components ; Handle $OSVer to match HPIA reqs for 20H1/20H2)
        (1.01.02 Show which drivers -listed in $UnselectList- are NOT part of driverpack)
        (1.01.03 fix multiple INF levels found in some driver softpaqs)
        (1.01.04 Added creation date to folder, zip file, ability to 'unselect' by Softpaq IDs)
        (1.01.05 Added ability to pass an unselect list from runstring)
        (1.01.06 Added start and end times, ability to remove superseeded softpaqs (-RemoveOlder switch)
        (1.02.00 Moved some code into functions for easier editing)
        (1.02.01 Added -TestOnly switch to avoid creating driverpack, added versions to final list output )
        (1.02.02 Added (-OutFormat) ability to craete WIM file, not just ZIP )

        Gary Blok (@gwblok) Recast Software Edits
        22.02.27 - Added "None" as option for output file, when I really just want the folder structure created to be moved into my own processes
        22.02.27 - changed date scheme from MMM.dd.yyyy to yyyy.MM.dd for easier scripting 


    NOTE: Existing downloaded drivers are NOT removed... must be cleared out if no longer needed
    NOTE: creation of WIM output requires Local Administrator rights (not so for ZIP)

    HP CMSL is required
    Output can be redirected: '.\New-Driverpack ... > driverpack.log' 

    NOTE: all runtime parameters have defaults (useful for testing in PS ISE)
    
    PARAMETERS:

    -Platform '880d' -OS 'win10' -OSVer '21H2' 
    -DownloadPath 'c:\tmp\stage'                         # defaults to 'C:\Staging'
    [-Unselectlist 'amd','nvidia','displaylink','wwan','USB-C Dock','sp122447'] 
    [-RemoveOlder]                                       # avoid inclusion of superseded softpaqs
    [-TestOnly]                                          # shows all work, but does not create driverpack
    [-OutFormat 'wim'|'zip'|'None']                             # defaults to ZIP # not useful with -TestOnly

    Usage: 
    with named parameters:
        .\New-Driverpack -Platform '880d' -OS 'win10' -OSVer '21H2' -DownloadPath 'c:\tmp\stage' -Unselectlist 'amd','nvidia','displaylink','wwan','USB-C Dock','sp122447' -RemoveOlder -TestOnly
        .\New-Driverpack -Platform '840 G8' -OS 'win10' -OSVer '21H2' -DownloadPath 'c:\tmp\stage' -Unselectlist 'amd','nvidia','displaylink','wwan','USB-C Dock','sp122447' -RemoveOlder -TestOnly
        # no unselect list
        .\New-Driverpack -Platform '840 G8' -OS 'win10' -OSVer '21H2' -DownloadPath 'c:\tmp\stage' -RemoveOlder -TestOnly
    with positional parameters:
        .\New-Driverpack '880d' 'win10' '21H2' 'c:\tmp\stage' 'amd','nvidia','displaylink','wwan','USB-C Dock','sp122447' -RemoveOlder|$True -TestOnly|$True
	    .\New-Driverpack '840 G8' 'win10' '21H2' 'c:\tmp\stage' 'amd','nvidia','displaylink','wwan','USB-C Dock','sp122447' -RemoveOlder|$True -TestOnly|$True
        # no unselect list
        .\New-Driverpack '840 G8' 'win10' '21H2' 'c:\tmp\stage' -RemoveOlder -TestOnly
#>
[CmdletBinding()]    # define defaults for driverpack - can be modified or be supplied in runstring
param(
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$platform='840 g8',          # '882C', or "1040 G8", or '880D' = '840 G8'
    [Parameter( Mandatory = $false, Position = 2 )] [ValidateSet('win10', 'win11')]
    [string]$OS='win10',
    [Parameter( Mandatory = $false, Position = 3 )] [ValidateSet('1909','2004','20H1','2009','20H2','21H1','21H2')]
    [string]$OSVer='21H2',
    [Parameter( Mandatory = $false, Position = 4 )]
    [string]$DownloadPath='C:\Staging',
    #############################################################################
    # Next is a list of drivers (by name or ID) to avoid in the driverpack
    #############################################################################
    [Parameter( Mandatory = $false, Position = 5 )]
    [array]$UnselectList, 
    #[array]$UnselectList=@('amd','nvidia','wwan','USB-C Dock'), # set some unneeded defaults, if desired
    [Parameter( Mandatory = $false, Position = 6 )]
    [switch]$RemoveOlder=$false,                  # set default to not remove superseded Softpaqs
    [Parameter( Mandatory = $false, Position = 7 )]
    [switch]$TestOnly=$false,
    [Parameter( Mandatory = $false, Position = 8 )] [ValidateSet('zip', 'wim', 'none')]
    [string]$OutFormat='wim'
) # param

$ScriptVersion = "1.02.02 (February 18, 2022)"

#############################################################################
# Function New_HPDriverPack
#   retrieves and unpacks each Softpaq to build the driverpack
#   uses the associated CVA file to find out the INF folders to include
#   uses standard PS command to create driverpack in ZIP format
#############################################################################
#   a. Download and extract each Softpaq
#   b. Download the corresponding CVA file
#   c. Get the individual INF file locations from each CVA file
#   d. search for the INF installation required paths
#   e. copy those paths to a driverpack folder
#   f. create driverpack in Zip format
#
Function New_HPDriverPack {
    [CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)] $pSoftpaqs,
        [Parameter(Mandatory = $true)] $pDownloadPath,
        [Parameter(Mandatory = $true)] $pExtractPath,
        [Parameter(Mandatory = $true)] $pOutputFormat
	)
    '== the following Drivers will be added to the driverpack'
    foreach ( $ientry in $pSoftpaqs) { 
        '   '+$ientry.id+' ['+$ientry.name +']'
        # fix folder naming issue when softpaq name contains '/',(ex. "Intel TXT/ACM" driver)
        $f_ExtractPath = $pDownloadPath+'\'+$ientry.id+'-'+$ientry.name.replace('/','_')
        $f_DestinationPath = $pExtractPath+'\'+$ientry.id+'-'+$ientry.name.replace('/','_')

        Get-Softpaq $ientry.id -Extract -FriendlyName -DestinationPath $f_ExtractPath 

        $f_AllPaths = (Get-SoftpaqMetadata $ientry.id).Devices_INFPath

        $f_INFPaths = @()
        for ( $i=0; $i -lt $f_AllPaths.count; $i++  ) {
            $f_INFPaths += $f_AllPaths.Values[$i] | where { $_ -ne $null } # remove Null entries from the list
        }
        # next seems convoluted but accounts for how INF paths are listed in diff CVA files
        $f_AllINFPaths = @()
        foreach ( $ientry in $f_INFPaths ) {
            if ( $ientry.count -eq 1 ) {
                $f_AllINFPaths += $ientry
            } else {
                for ( $i=0;$i -lt $ientry.count; $i++ ) {
                    $f_AllINFPaths += [array]$ientry[$i]
                } 
            }
        } # foreach ( $ientry in $f_INFPaths )

        foreach ( $iPath in ($f_AllINFPaths | Sort-Object | Get-Unique) ) {
            Copy-Item "$($f_ExtractPath)\$($iPath)" $f_DestinationPath -Force -Recurse
        }
    } # foreach ( $ientry in $pSoftpaqs)

    # finally, create an archive driverpack
    "== creating/compressing driverpack in $pOutputFormat format" | Out-Host
    switch ( $pOutputFormat ) {
        'zip' { 
            Compress-Archive -Path $pExtractPath -DestinationPath $pExtractPath'.zip' -CompressionLevel optimal -Force 
            '== created driverpack '+$pExtractPath+'.zip' | Out-Host
            }
        'wim' { 
            if ( Test-Path "$($pExtractPath).wim" ) {    # New-WindowsImage will not override existing file
                '== Removing existing file: '+$pExtractPath+'.zip' | Out-Host
                Remove-Item -Path "$($pExtractPath).wim" -Force   
            }
            New-WindowsImage -CapturePath $pExtractPath -ImagePath $pExtractPath'.wim' -CompressionType Max `
                -LogPath $pExtractPath'\DISM.log' -Name (Split-Path $pDownloadPath -leaf)
            '== created driverpack '+$pExtractPath+'.wim' | Out-Host
            }
        'none' {             
            '== Skipped creating output file' | Out-Host
            }
    } # switch ( $pOutputFormat )

} # Function New_HPDriverPack
#############################################################################

#############################################################################
# Function Remove_Unselected
#   returns a softpaq list minus any Softpaq entries described in the 
#   unselected runtime option list
#############################################################################
#
Function Remove_Unselected {
    [CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)] $pFullSoftpaqList,
        [Parameter(Mandatory = $true)] [array]$pUnselectList,
        [Parameter(Mandatory = $true)] [boolean]$pUnselectListAsArg
	)
    if ( $pUnselectListAsArg ) {
        "{Removing unselected entries (-UnselectList runtime option)}" | Out-Host
    } else {
        "{Removing unselected entries (-UnselectList list from script)}" | Out-Host
    }
    
    $l_DPBList = @()       # list of drivers that will be selected from the full list
    $l_Unselected = @()    # list of drivers that were unselected (to display)
    for ($i=0;$i -lt $pFullSoftpaqList.Count; $i++ ) {
        $iUnselectMatched = $null
        # see if the entries contain Softpaqs by name or ID, and remove from list
        foreach ( $iList in $pUnselectList ) { 
            if ( ($pFullSoftpaqList[$i].name -match $iList) -or ($pFullSoftpaqList[$i].id -like $iList) ) { 
                $iUnselectMatched = $true ; $l_Unselected += $pFullSoftpaqList[$i] 
            } 
        } # foreach ( $iList in $UnselectList )
        if ( -not $iUnselectMatched ) { $l_DPBList += $pFullSoftpaqList[$i] }
    } # for ($i=0;$i -lt $lFullDPBList.Count; $i++ )
    "== Unselected drivers: " | Out-Host
    foreach ( $iun in $l_Unselected ) { "   $($iun.id) $($iun.Name) [$($iun.Category) ]" | Out-Host }

    , $l_DPBList  # return the list of softpaqs

} # Function Remove_Unselected
#############################################################################

#############################################################################
# Function Remove_Superseded
#   returns a softpaq list minus any Softpaq entries that are superseded
#############################################################################
#
Function Remove_Superseded {
    [CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)] $pFullSoftpaqList
    )
    "{Removing superseded entries  (-RemoveOlder switch option)}" | Out-Host
    #############################################################################
    # 1. get a list of Softpaqs with multiple entries
    $l_TmpList = @()
    foreach ( $iEntry in $pFullSoftpaqList ) {
        foreach ( $i in $pFullSoftpaqList ) {    # search for entries that are same names as $iEntry
            if ( ($i.name -match $iEntry.name) -and (-not ($i.id -match $iEntry.id)) -and ($iEntry -notin $l_TmpList)) {
                $l_TmpList += $iEntry         # found an softpaq name with multiple versions
            }
        } # foreach ( $i in $pFullSoftpaqList )
    } # foreach ( $iEntry in $pFullSoftpaqList )
    "== These drivers have multiple Softpaqs (have superseeded entries)" | Out-Host
    foreach ( $iun in $l_TmpList ) { "   $($iun.id) $($iun.Name) [$($iun.Category) ]" | Out-Host }    
    #############################################################################
    # 2. from the $lTmpList list, find the latest (highest sp number softpaq) of each
    $l_FinalTmpList = @()
    foreach ( $iEntry in $l_TmpList ) {
        foreach ( $i in $l_TmpList ) {    
            if ( ($i.name -match $iEntry.name) -and 
                 ($i.id -notmatch $iEntry.id) -and 
                 ([int]$i.id.substring(2) -lt [int]$iEntry.id.substring(2)) -and
                 ($iEntry.name -notin $l_FinalTmpList.name)) {
                $l_FinalTmpList += $iEntry         
            } # if ...
        } # foreach ( $i in $l_TmpList )
    } # foreach ( $iEntry in $l_TmpList )
    "== These softpaqs made the cut - higher SP #s" | Out-Host
    foreach ( $iun in $l_FinalTmpList ) { "   $($iun.id) $($iun.Name) [$($iun.Category) ]" | Out-Host }
    #############################################################################
    # 3. lastly, remove superseeded drivers from main driverpack list
    $l_FinalDPBList = @()
    foreach ( $iEntry in $pFullSoftpaqList ) {
        if ( ($iEntry.name -notin $l_TmpList.name) -or ($iEntry.id -in $l_FinalTmpList.id) ) {
                if ($iEntry.name -notin $l_FinalDPBList.name) { $l_FinalDPBList += $iEntry }
        }
    } # foreach ( $iEntry in $lDPBList )

    , $l_FinalDPBList           # return list of Softpaqs without the superseded Softpaqs

} # Function Remove_Superseded
#############################################################################

# ---------------------------------------------------------------------------
# Start of script
# ---------------------------------------------------------------------------
'Script version: '+$ScriptVersion
'Script Start: '+(Get-date)

Switch ( $OSVer ) { '20H1' { $OSVer = '2004' } ; '20H2' { $OSVer = '2009' } }

#############################################################################
# Manage -platform option for model name, instead of SysID (always 4 chars long)
#############################################################################
if ( $platform.Length -eq 4 ) {    # SysID always 4 chars long
    $lDevices = Get-HPDeviceDetails -Platform $platform
} else {
    $lDevices = Get-HPDeviceDetails -Like $platform    # assume name as argument
} # else if ( $platform.Length -eq 4 )

switch ( $lDevices.SystemID.count ) {
    0 { "Platform '$($platform)' NOT found" ; exit }
    1 { $platform = $lDevices.SystemID ; $lplatformName = $lDevices.Name }
    Default { "Multiple platforms available - Use '-Platform name' option" | Out-Host
                foreach ( $idev in $lDevices ) { "$($idev.SystemID): $($idev.Name)" | Out-Host }
                exit 
        }
} # switch ( $lDevices.SystemID.count )
#############################################################################

'== Creating Driverpack for Platform ['+$Platform+'] '+$lplatformName

#############################################################################
# find specific drivers in list to create a driverpack (DPB = true)
#
$lSoftpaqList = Get-SoftpaqList -platform $Platform -os $OS -osver $OSVer
$lFullDPBList = $lSoftpaqList | where { ($_.DPB -like 'true') }

#############################################################################
# remove any Softpaqs matching names in $UnselectList from the returned list
#
$DPBList = @()
if ( $UnselectList.Count -gt 0 ) {
    $UnselectListAsArgument = $PSBoundParameters.ContainsKey("UnselectList")
    $DPBList = Remove_Unselected $lFullDPBList $UnselectList $UnselectListAsArgument
} else {
    $DPBList = $lFullDPBList | foreach { $_ } 
}

#############################################################################
# remove any Softpaqs matching names in $UnselectList from the returned list
#
if ( $RemoveOlder ) {
    $FinalListofSoftpaqs = @()
    $FinalListofSoftpaqs = Remove_Superseded $DPBList
    $DPBList = $FinalListofSoftpaqs | foreach { $_ } 
} # if ( $RemoveOlder )

"{Pre-processing completed}" | Out-Host
"== Final list of Softpaqs for DriverPack" | Out-Host
foreach ( $iFinal in $DPBList ) { "   $($iFinal.id) $($iFinal.Name) [$($iFinal.Category) ]  Version:$($iFinal.Version)" | Out-Host }

#############################################################################
# show which selected drivers contain UWP/appx applications (UWP = true)
#
'== the following selected Drivers contain UWP/appx Store apps' | Out-Host
$UWPList = $DPBList | where { $_.UWP -like 'true' }
foreach ( $iUWP in $UWPList ) { "   $($iUWP.id) $($iUWP.Name) [$($iUWP.Category) ]" | Out-Host }

$PWDcurrent = Get-Location    # restore path to this location at the end

#############################################################################
# now create the driverpack
#
if ( $TestOnly ) {
     "{TestOnly mode complete. No Driverpack created}" | Out-Host
} else {
    "{Creating driverpack}" | Out-Host
    $DriverPackHdr = "$($Platform)_$($OS)_$($OSVer)"
    $softpaqDownloadRoot = "$($DownloadPath)\$($DriverPackHdr)."+(Get-Date -Format "yyyyMMdd")

    $driverPackRoot = "$($DownloadPath)\DriverPack\$($DriverPackHdr)."+(Get-Date -Format "yyyyMMdd")
    '== Download and Extract Path: '+$softpaqDownloadRoot
    '== DriverPack to be found at: '+$driverPackRoot

    #############################################################################
    # make sure the root download path exists
    #
    if ( -not (Test-Path $softpaqDownloadRoot) ) {
        New-Item -Path $softpaqDownloadRoot -ItemType directory | out-null
    }
    Set-Location $softpaqDownloadRoot
    New_HPDriverPack $DPBList $softpaqDownloadRoot $driverPackRoot $OutFormat
}
Set-Location $PWDcurrent

'Script End: '+(Get-date)
