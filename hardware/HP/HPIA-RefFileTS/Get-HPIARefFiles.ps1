<# Get-HPIA Reference Files

Gary Blok | @gwblok | GARYTOWN.COM
Set-ReferenceFileSoftpaq from Dan Felman @HP

Update these Variables:
$ReferenceFileLocation  - Update this to where you want to keep your Reference File Package
$OSTable = OS Version you're going to run HPIA on.  You need a reference file PER Build you're going to use it on
AKA Windows 10, 21H2, 22H2, etc & Windows 11 21H2, 22H2, etc


#>


#Models we'll grab reference files for:
$ModelsTable= @(

#EliteBook
@{ Model ="HP EliteBook 835 G8 Notebook PC"; Platform = "8895"}
@{ Model ="HP EliteBook 840 G2"; Platform = "2216"}
@{ Model ="HP EliteBook 840 G3"; Platform = "8079"}
@{ Model ="HP EliteBook 840 G5"; Platform = "83B2"} #ARIA
@{ Model ="HP EliteBook 840 G6"; Platform = "8549"} #ARIA
@{ Model ="HP EliteBook 840 G7 Notebook PC"; Platform = "8723"} #ARIA
@{ Model ="HP EliteBook 840 G8 Notebook PC"; Platform = "8AB8"}
@{ Model ="HP EliteBook 840 G8 Notebook PC"; Platform = "8AB3"}
@{ Model ="HP EliteBook 840 G8 Notebook PC"; Platform = "880D"} 
@{ Model ="HP EliteBook 845 G7 Notebook PC"; Platform = "8760"} #ARIA
@{ Model ="HP EliteBook 850 G8 Notebook PC"; Platform = "8846"}
#EliteBook X360
@{ Model ="HP EliteBook x360 830 G5"; Platform = "853D"}
@{ Model ="HP EliteBook x360 1030 G2"; Platform = "827D"}
@{ Model ="HP EliteBook x360 1030 G3"; Platform = "8438"}
@{ Model ="HP EliteBook x360 1040 G5"; Platform = "8470"}
@{ Model ="HP EliteBook x360 1040 G6"; Platform = "857F"}
@{ Model ="HP EliteBook x360 1040 G7 Notebook PC"; Platform = "876D"}
@{ Model ="HP EliteBook x360 1040 G8 Notebook PC"; Platform = "8720"}
@{ Model ="HP EliteBook x360 1040 G9 Notebook PC"; Platform = "896D"}
#ZBook
@{ Model ="HP ZBook Create G7 Notebook PC"; Platform = "8736"}
@{ Model ="HP ZBook Studio x360 G5"; Platform = "844F"}
@{ Model ="HP ZBook Fury 15.6 inch G8 Mobile Workstation PC"; Platform = "8870"}
@{ Model ="HP ZBook Firefly 14 G7 Mobile Workstation"; Platform = "8724"} #ARIA
#Duplicate Platform @{ Model ="HP ZBook Firefly 15 G7 Mobile Workstation"; Platform = "8724"}
@{ Model ="HP ZBook Fury 15 G7 Mobile Workstation"; Platform = "8783"}
@{ Model ="HP ZBook Firefly 14 inch G8 Mobile Workstation PC"; Platform = "880D"}
@{ Model ="HP ZBook Studio G7 Mobile Workstation"; Platform = "8736"} #
@{ Model ="HP ZBook Studio 15.6 inch G8 Mobile Workstation PC"; Platform = "8873"}
@{ Model ="HP ZBook Power 15.6 inch G8 Mobile Workstation PC"; Platform = "888D"}
@{ Model ="HP ZBook 15 G3"; Platform = "80D5"}
@{ Model ="HP ZBook 15 G5"; Platform = "842A"}
@{ Model ="HP ZBook 15 G6"; Platform = "860F"} #ARIA
#Elite Dragonfly
@{ Model ="HP Elite Dragonfly"; Platform = "861F"}
@{ Model ="HP Elite Dragonfly G2 Notebook PC"; Platform = "8716"}
@{ Model ="HP Elite Dragonfly Max Notebook PC"; Platform = "8890"}
@{ Model ="HP Elite Dragonfly 13.5 inch G3 Notebook PC"; Platform = "897F"}
#Z Workstations
@{ Model ="HP Z640 Workstation"; Platform = "212A"}
@{ Model ="HP Z6 G4 Workstation"; Platform = "81C6"}
@{ Model ="HP Z8 G4 Workstation"; Platform = "81C7"}
@{ Model ="HP Z2 Mini G9 Workstation"; Platform = "895E"}
#ProBook
@{ Model ="HP ProBook 440 G7"; Platform = "869D"}
@{ Model ="HP ProBook 440 G8 Notebook PC"; Platform = "87E0"}
@{ Model ="HP ProBook 630 G8 Notebook PC"; Platform = "87EA"} #ARIA
#ProDesk
@{ Model ="HP ProDesk 600 G2 SFF"; Platform = "805D"}
@{ Model ="HP ProDesk 600 G1 SFF"; Platform = "18E7"}
@{ Model ="HP ProDesk 600 G3 SFF"; Platform = "82B4"}
@{ Model ="HP ProDesk 600 G4 DM"; Platform = "83EF"}
#EliteDesk
@{ Model ="HP EliteDesk 705 G3 DM"; Platform = "8266"}
)



$ModelsTable= @(
@{ Model ="HP EliteBook x360 830 G5"; Platform = "853D"}

)

#Get all Platforms HPIA supports:
$TotalMachines = Get-HPDeviceDetails -Like *
$Platforms = $TotalMachines.SystemID | Select-Object -Unique

#OS Builds for Each Model that we'll create Reference files for:
$OSTable = @(
@{ OS = 'win10'; OSVer = '21H2'}
@{ OS = 'win10'; OSVer = '22H2'}
@{ OS = 'win11'; OSVer = '21H2'}
@{ OS = 'win11'; OSVer = '22H2'}
)

$Date = Get-date -Format "yyyyMMdd"
#Location to create Reference files
$ReferenceFileLocation = "F:\ImageAssisant\ReferenceFiles-$($Date)"

#Temp Cache where files are being built before moved.
$CacheDir = "$env:temp\HPRefFiles\Cache"

try {
    [void][System.IO.Directory]::CreateDirectory($CacheDir)
    [void][System.IO.Directory]::CreateDirectory($ReferenceFileLocation)
}
catch {throw}


Function Set-ReferenceFileSoftpaq {
<#
.Name
    Set-ReferenceFileSoftpaq
    by Dan Felman/HP Inc
.Synopsis
    Parse an HPIA reference file and replace a Softpaq with a different version 

.DESCRIPTION
    Script downloads and parses an HPIA reference file to replace a Softpaq solution 
    with a superseded version
    It can also display a supersede chain of Softpaqs for a current Softpaq in the Reference File
    If changes are made, a backup is made of the original with extension '.bak'    

.Notes
    Created: 8/29/2022
    Version: 1.10.11

    Author : Dan Felman
    
    Disclaimer: This script is provided "AS IS" with no warranties, confers no rights and is not supported by the author.

    License information for HP Client Management Script Library: https://developers.hp.com/node/11493

    -ReplaceSoftpaq AND -ToSoftpaq <Softpaq_IDs> MUST exist in Reference File
    
    How to find Softpaqs w/CMSL commands: 
        Ex. find Nvidia driver Softpaq
            Get-SoftpaqList | ? { $_.name -match 'nvidia' }
        Ex. find Intel nic driver Softpaq
            Get-SoftpaqList | ? { $_.Category -match 'network' -and ($_.name -match 'Intel') }

    Runtime Options: 
        -Platform <SysID>               # REQUIRED - also positional
        -OS Win10|win11                 # REQUIRED - also positional
        -OSVer <as per Get-SoftpaqList> # REQUIRED - also positional
        -ReplaceSoftpaq <Softpaq_ID>    # REQUIRED
                                        # a .bak file is created, but ONLY ONCE, then it is overwritten
        [-ToSoftpaq <Softpaq_ID>]       # will use 'Previous' SOfptaq if omitted from command line
        [-CacheDir <path>]              # where Reference file will be downloaded
                                          If omitted, will use current folder
        [-ReferenceFile <path>]         # location of reference XML file to modify
                                          instead of d/l latest from HP
                                          (-CacheDir option not used in this case)
        [-ListNoSupersedes]             # Lists latest Softpaq with no Superseded entry in Ref File
        [-ListByCategory]               # lists Softpaqs by Category
        [-ListSuperseded <Softpaq_ID>]  # Softpaq_ID must be latest recommendation

        All output can be routed to text file: ' > out.txt'

.Example
         // download and update a reference file
        Set-ReferenceFileSoftpaq -Platform 842a -OS win10 -OSVer 2009 -ReplaceSoftpaq sp139952 [-ToSoftpaq sp139166] [CacheDir <path>]
.Example
         // update already downloaded reference file, make a backup of existing file (ONCE)
        Set-ReferenceFileSoftpaq 842a win10 21H2 -ReplaceSoftpaq sp139952 -ReferenceFile .\842a_64_10.0.2009.xml
.Example
         // show Softpaqs that do not supersede any version
        Set-ReferenceFileSoftpaq 842a win10 21H2 -ListNoSupersedes | ListByCategory <bios,firmware,driver,dock,etc>
.Example
        // find the "intel wlan" driver in reference file
        Set-ReferenceFileSoftpaq1.01.06.ps1 842a win10 2009 -ListByCategory 'driver' | 
            where { $_ -match 'intel wlan'} 
.Example
        // list the superseded chain for a Softpaq
        Set-ReferenceFileSoftpaq1.01.06.ps1 842a win10 2009 -ListSuperseded sp139952

.Requirements
    The HP Client Management Script Library is required.
        https://developers.hp.com/hp-client-management/doc/client-management-script-library
    
.Version History
    1.01.00 8/2/2022 obtain Ref File with CMSL command
             add -platform -OS and -OSVer in command line
    1.01.01 8/3/2022 Better management of cache folder 
            Using current folder for local use of updated reference file
    1.01.02 8/9/2022 fixed -ToReplace search error
    1.01.03 8/9/2022 Added source reference file option
    1.01.05 8/15/2022 created functions
             Fixed issue where superseded entry was ALSO in main /Solutions
    1.01.06 8/16/2022 Added -ListNoSupersedes switch
             Added -ListByCategory <category array> (e.g. bios, or 'bios,driver')
    1.01.10 8/17/2022 added -ListSuperseded <SoftpaqID>, fixed bugs
    1.10.11 8/29/2022 made function out of -ListSuperseded option

#>

param(
    [Parameter( Mandatory = $True, Position = 0 )] 
    [string]$Platform,
    [Parameter( Mandatory = $True, Position = 1 )] [ValidateSet('win10', 'win11')]
    [string]$OS,
    [Parameter( Mandatory = $True, Position = 2 )] 
    [string]$OSVer,
    [Parameter( Mandatory = $false )] 
    $CacheDir,
    [Parameter( Mandatory = $false )] 
    $ReplaceSoftpaq,
    [Parameter( Mandatory = $false )] 
    $ToSoftpaq,
    [Parameter( Mandatory = $false )] 
    $ReferenceFile,
    [Parameter( Mandatory = $false )] 
    [switch]$ListNoSupersedes,
    [Parameter( Mandatory = $false )] 
    $ListByCategory,
    [Parameter( Mandatory = $false )] 
    $ListSuperseded
) # param

$ReferenceFileSoftpaqVersion = '1.01.11'
'Set-ReferenceFileSoftpaq - version '+$ReferenceFileSoftpaqVersion

#################################################################
# Function Get_ReferenceFileArg
#
#   1) copy reference file argument to the caching folde
#   2) if file with same reference file name exists in 
#      current folder, renames it as .bak (only once)
#   3) copies file from cache folder to current folder
#
#   Returns: path of reference file in current folder
#################################################################

Function Get_ReferenceFileArg {
    [CmdletBinding()]
	param( $pReferenceFile, $pCacheDir ) 

    if ( Test-Path $pReferenceFile ) {
        $f_DestinationXmlFile = $pCacheDir+'\'+(Split-Path $pReferenceFile -Leaf) # Destination path
        Try {
            $Error.Clear()
            Copy-Item $pReferenceFile -Destination $pCacheDir'\cache' -Force -EA Stop
            $f_CachedReferenceFile = $pCacheDir+'\cache\'+(Split-Path $pReferenceFile -Leaf)
            if ( Test-Path $f_DestinationXmlFile) {
                Move-Item -Path $f_DestinationXmlFile -Destination $f_DestinationXmlFile'.bak' -Force -EA Stop
            }
            Copy-Item $f_CachedReferenceFile -Destination $f_DestinationXmlFile -Force -EA Stop
        } catch {
            $error[0].exception          # $error[0].exception.gettype().fullname 
        } # Catch
    } else {
        $f_DestinationXmlFile = $pReferenceFile
    } # else if ( Test-Path $pReferenceFile )
    
    return $f_DestinationXmlFile

} # Function Get_ReferenceFileArg
#################################################################

#################################################################
# Function Get_ReferenceFileFromHP
#
#   1) retrieves latest reference file from HP to cache folder
#      (with CMSL Get-SofptaqList)
#   2) finds downloaded reference (xml) file
#   3) copies file from cache folder to current folder
#      replacing file if same file name exists in folder
#
#   Returns: path of reference file in current folder
#################################################################

Function Get_ReferenceFileFromHP {
    [CmdletBinding()]
	param( $pPlatform, $pOS, $pOSVer, $pCacheDir ) 

    Try {
        $Error.Clear()
        get-softpaqList -platform $pPlatform -OS $pOS -OSVer $pOSVer -Overwrite 'Yes' -CacheDir $pCacheDir -EA Stop | Out-Null
    } Catch {
        $error[0].exception          # $error[0].exception.gettype().fullname 
        return
    }
    # find the downloaded Reference_File.xml file
    $f_XmlFile = Get-Childitem -Path $pCacheDir'\cache' -Include "*.xml" -Recurse -File |
        where { ($_.Directory -match '.dir') -and ($_.Name -match $pPlatform) `
            -and ($_.Name -match $pOS.Substring(3)) -and ($_.Name -match $pOSVer) }

    Copy-Item $f_XmlFile -Destination $Pwd.Path -Force

    return "$($Pwd.Path)\$($f_XmlFile.Name)"   # final destination in current folder

} # Function Get_ReferenceFileFromHP
#################################################################

#################################################################
# Function ListSupersededChain
#
#   1) retrieves latest reference file from HP to cache folder
#      (with CMSL Get-SofptaqList)
#   2) scans the supersede chaing for the argument
#
#################################################################

Function ListSupersededChain { 
    [CmdletBinding()]
	param( $pSolutionsNodes, $pssNodes, [string]$pListSuperseded ) 

    $f_ssNode = $pSolutionsNodes | where { $_.id -eq $pListSuperseded }
    if ( $f_ssNode ) {
        "// List of Superseded Softpaqs for $pListSuperseded $($f_ssNode.name)"
        "   $($f_ssNode.id) / $($f_ssNode.version)"
        # check if superseded is in /Solutions by mistake first (assume only possible once)
        $f_ssNodeNext = $pSolutionsNodes | where { $_.id -eq $f_ssNode.supersedes }
        if ( $f_ssNodeNext ) {
            ".... $($f_ssNodeNext.id) / $($f_ssNodeNext.version)"
            $f_ssNode = $pSolutionsNodes | where { $_.id -eq $f_ssNode.supersedes }
        }
        # ... find and list the superseded chain of Softpaqs
        do {
            if ( $f_ssNode = $pssNodes | where { $_.id -eq $f_ssNode.supersedes } ) {
                "   $($f_ssNode.id) / $($f_ssNode.version)"
            } else {
                break
            }
        } while ( $f_ssNode -ne $null )
    } else {
        'Softpaq not found'
    } # if ( $f_ssNode )

} # Function ListSupersededChain
#################################################################

#################################################################
# Step 1. make sure Reference File is available
#################################################################

# Set up the Cache folder path that hosts the TEMP reference file

if ( $CacheDir -eq $null ) { 
    $CacheDir = $Pwd.Path 
}
$CacheDir = (Convert-Path $CacheDir)
"-- Caching folder: $CacheDir\cache"

# check for -ReferenceFile argument, in case we should use it

if ( $ReferenceFile -eq $null ) {
    $ReferenceFile = Get_ReferenceFileFromHP $Platform $OS $OSVer $CacheDir
} else {
    $ReferenceFile = Get_ReferenceFileArg $ReferenceFile $CacheDir
} # else if ( $ReferenceFile -ne $null )

if ( Test-Path $ReferenceFile ) {
    "-- Using Reference file '$ReferenceFile'"
    $xmlContent = [xml](Get-Content -Path $ReferenceFile)
} else {
    return "-- Can not access Reference file: '$ReferenceFile'"
}
#################################################################
# Step 2. Get pointers to the difference nodes in XML file
#################################################################

# get each section of the XML file
$SystemNode = $xmlContent.SelectNodes("ImagePal/SystemInfo")
$SolutionsNodes = $xmlContent.SelectNodes("ImagePal/Solutions/UpdateInfo")
$ssNodes = $xmlContent.SelectNodes("ImagePal/Solutions-Superseded/UpdateInfo")
$swInstalledNodes = $xmlContent.SelectNodes("ImagePal/SystemInfo/SoftwareInstalled/Software")
$deviceNodes = $xmlContent.SelectNodes("ImagePal/Devices/Device")

#################################################################
# Step 3. manage esoteric options, if passed as arguments
#################################################################

###################################################
# List all Softpaqs that do not supersede any other
###################################################
# find all Softpaqs that do not Superseded any other
if ( $ListNoSupersedes ) {
    "// Liting Softpaqs with no Superseded version"
    foreach ( $entry in $SolutionsNodes ) {
        if ( $entry.Supersedes -eq $null ) {
            "   $($entry.id) $($entry.name) / $($entry.version)"
        }
    } # foreach ( $entry in $SolutionsNodes )
    return
} # if ( $ListNoSupersedes )

###################################################
# List Softpaqs by each category (as per cmd line)
###################################################
if ( $ListByCategory ) {
    [array]$CatArray = $ListByCategory.split(',')
    "// Listing by Category $ListByCategory"

    foreach ( $i in $CatArray ) {
        "// Category: $($i)"
        $SoftpaqByCategoryNodes = $SolutionsNodes | where { $_.category -match $i }
        foreach ( $sol in $SoftpaqByCategoryNodes ) {
            if ( $sol.category -match $i ) {
                "   $($sol.id) $($sol.name) / $($sol.version)"
            }
        } # foreach ( $sol in $SoftpaqByCategoryNodes )
    } # foreach ( $i in $CatArray )
    return
} # if ( $ListCategory )

###################################################
# List the Superseded chain for a specific Softpaq
###################################################
if ( $ListSuperseded ) {
    ListSupersededChain $SolutionsNodes $ssNodes $ListSuperseded
    return # nothing else to do, so exit
} # if ( $ListSuperseded -ne $null )

#################################################################
# Step 4. Find the Softpaq to replace and its replacement in file
#################################################################

###################################################
# a) Find -ReplaceSoftpaq to replace in /Solutions
###################################################
$SoftpaqNode = $SolutionsNodes | where { $_.id -eq $ReplaceSoftpaq }

"-- Begin XML reference file modification"
if ( $SoftpaqNode -eq $null ) {
    return "Softpaq $ReplaceSoftpaq not found in Reference File"
}
"-- /Solutions: ReplaceSoftpaq Found - $ReplaceSoftpaq/$($SoftpaqNode.Version) - $($SoftpaqNode.Category)"

###################################################
# b) Find -ToSoftpaq in /Solutions-Superseded
###################################################

if ( $ToSoftpaq -eq $null ) { $ToSoftpaq = $SoftpaqNode.Supersedes }
if ( $ToSoftpaq -eq $null ) { return '-- Error: No superseded Softpaq listed' }

# ... first check for the node in /Solutions (can be a file ERROR - SHOULD BE REPORTED)
$ssNode = $SolutionsNodes | where { $_.id -eq $ToSoftpaq }
if ( $ssNode.id -eq $null ) {

    # ... next, search the supersede chain for the Softpaq node
    do {
        #$ssNode = $ssNodes | where { $_.id -eq $SSSoftpaqID }
        $ssNode = $ssNodes | where { $_.id -eq $ToSoftpaq }
        if ( ($SSSoftpaqID = $ssNode.Supersedes) -eq $null) { break }
    } while ( ($ssNode.id -ne $ToSoftpaq) -and ($SSSoftpaqID -ne $null) )

    if ( $ssNode.id -ne $ToSoftpaq ) {
        if ( $ssNode -eq $null ) {
            return "-- ToSoftpaq not found - $($ToSoftpaq) must be a superseded Softpaq for $($SoftpaqNode.id)"
        } else {
            "-- /Solutions: ToSoftpaq found - $($ssNode.id)/$($ssNode.Version)"
        } # else if ( $ssNode -eq $null )
    } else {
        "-- /Solutions-Superseded: ToSoftpaq found - $($ssNode.id)/$($ssNode.Version)"
    } # else if ( $ssNode.id -ne $ToSoftpaq )

} # if ( $ssNode.id -eq $null )

#################################################################
# Step 5. execute the replacement in the local reference file
#################################################################

###################################################
# Handle the case this is a BIOS
###################################################
#if BIOS Softpaq, check /System node area (top of file)

if ( ($SoftpaqNode.Category -eq 'BIOS') -and ($SystemNode.System.Solutions.UpdateInfo.IdRef -eq $ReplaceSoftpaq) ) {
    $SystemNode.System.Solutions.UpdateInfo.IdRef = $ssNode.Id 
    "-- /System: (/Category:BIOS) updated /UpdateInfo IdRef= entry"
}

###################################################
# Solutions: Replace contents of Softpaq node w/replacement
###################################################

$SoftpaqNode.Supersedes = $ssNode.Supersedes
$SoftpaqNode.ColId = $ssNode.ColId
$SoftpaqNode.ItemId = $ssNode.ItemId
$SoftpaqNode.Id = $ssNode.Id
$SoftpaqNode.Name = $ssNode.Name
$SoftpaqNode.Category = $ssNode.Category
$SoftpaqNode.Version = $ssNode.Version
$SoftpaqNode.Vendor = $ssNode.Vendor
$SoftpaqNode.ReleaseType = $ssNode.ReleaseType
$SoftpaqNode.SSMCompliant = $ssNode.SSMCompliant
$SoftpaqNode.DPBCompliant = $ssNode.DPBCompliant
$SoftpaqNode.SilentInstall = $ssNode.SilentInstall
$SoftpaqNode.Url = $ssNode.Url
$SoftpaqNode.ReleaseNotesUrl = $ssNode.ReleaseNotesUrl
$SoftpaqNode.CvaUrl = $ssNode.CvaUrl
$SoftpaqNode.MD5 = $ssNode.MD5
$SoftpaqNode.SHA256 = $ssNode.SHA256
$SoftpaqNode.Size = $ssNode.Size
$SoftpaqNode.DateReleased = $ssNode.DateReleased
$SoftpaqNode.SupportedLanguages = $ssNode.SupportedLanguages
$SoftpaqNode.SupportedOS = $ssNode.SupportedOS
$SoftpaqNode.Description = $ssNode.Description
"-- /solutions: ReplaceSoftpaq node Updated [$($ReplaceSoftpaq) with $($ssNode.id)]"

###################################################
# SoftwareInstalled: Update contents of node w/replacement
###################################################

$swInstalledFound = $false
foreach ( $sw in $swInstalledNodes ) {
    if ( $sw.Solutions.UpdateInfo.IdRef -eq $ReplaceSoftpaq ) {
        $sw.Version = [string]$ssNode.Version
        $sw.Vendor = [string]$ssNode.Vendor
        $sw.Solutions.UpdateInfo.IdRef = $SoftpaqNode.Id
        $swInstalledFound = $true
    }
} # foreach ( $sw in $swInstalledNodes )

if ( $swInstalledFound ) {
    "-- /SoftwareInstalled: Replaced values for ReplaceSoftpaq $($ReplaceSoftpaq)"
} else {
    "-- /SoftwareInstalled: No matches found for ReplaceSoftpaq $($ReplaceSoftpaq)"
}

###################################################
# Devices: Update contents of node w/replacement
###################################################

$DeviceCount = 0
foreach ( $dev in $deviceNodes ) {
    if ( $dev.Solutions.UpdateInfo.IdRef -eq $ReplaceSoftpaq ) {
        $DeviceCount += 1
        $dev.DriverDate = [string]$ssNode.DateReleased
        $Dev.DriverProvider = [string]$ssNode.Vendor
        $Dev.DriverVersion = [string]$ssNode.Version   # $Dev.DriverVersion comes from Device Manager
        $dev.Solutions.UpdateInfo.IdRef = $ssNode.Id
    }
} # foreach ( $dev in $deviceNodes )

if ( $DeviceCount -gt 0 ) {
    "-- /Devices: Found $DeviceCount matches - Replaced info with new Softpaq $([string]$ssNode.Id)"
} else {
    "-- /Devices: No matches found for ReplaceSoftpaq $($ReplaceSoftpaq)"
} # else if ( $DeviceCount -gt 0 )

#################################################################
# Step 6. save modified file back
#################################################################

$xmlContent.Save((Convert-Path $ReferenceFile))
"-- Reference File Updated: '$ReferenceFile'"

}


Set-Location -Path $ReferenceFileLocation
    
foreach ($Platform in $Platforms){
    #$Model = ($ModelsTable | Where-Object {$_.Platform -eq $Platform}).Model
   foreach ($OS in $OSTable.OS | Select-Object -Unique){
        foreach ($OSVer in ($OSTable | Where-Object {$_.OS -eq $OS}).osver){
	        Write-Host "-- $Platform | $OS | $OSVer --" -ForegroundColor Cyan
            Set-ReferenceFileSoftpaq -Platform $Platform -OS $OS -OSVer $OSVer -CacheDir $CacheDir
        }
   }
}
