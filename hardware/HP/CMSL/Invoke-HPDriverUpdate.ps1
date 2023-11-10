Function Invoke-HPAnalyzer {
    <#
    .Name
        Analyzer.ps1

    .Synopsis
        Analyzer displays possible Softpaq updates available for a platform

    .DESCRIPTION
        Analyzer finds 'BIOS', 'Driver', 'Software' Softpaqs that can update the current system

    .Notes  
        Author: Dan Felman/HP Inc
        11/30/2022 - initial release 1.00.01

    .Dependencies
        Requires HP Client Management Script Library
        HP Business class devices (as supported by HPIA and HP CMSL)
        Internet access. Analyzer downloads content from Internet


    .Parameters
        -a|-All                 -- [switch] List All Softpaqs and their status
        -r|-RecommendedSoftware -- [switch] include HP Software HP recommends
        -s|-ShowHWID            -- [switch] list Hardware ID's matched for each driver
        -d|-DebugOutput         -- [switch] add additional info to output 
        -l|-LogFile <file_Path> -- log all output to file_path
        -c|-CsvLog <file.csv>   -- create CSV log file output
        -n|-NoDots              -- [switch] avoid output of '.' while looping (useful when logging output)

    .Examples
        # check current device for updates updates
        Analyzer.ps1

        # check current device, with ALL output to file - output updates and up to date Softpaqs
        Analyzer.ps1 -NoDots -LogFile Out.txt

        # check current platform, and matching Hardware IDs, include info on ALL Softpaqs
        Analyzer.ps1 -ShowHWID -All
    #>
    [CmdletBinding()]
    param(
    #    [Parameter(Mandatory = $false)]
    #    [String]$Target,
        [Parameter(Mandatory = $false)]
        [switch]$all,
        [Parameter(Mandatory = $false)]
        [switch]$RecommendedSoftware,
        [Parameter(Mandatory = $false)]
        [switch]$ShowHWID,
        [Parameter(Mandatory = $false)] 
        [switch]$DebugOutput,
        [Parameter(Mandatory = $false)]
        [String]$XmlFile,
        [Parameter(Mandatory = $false)]
        [String]$CsvLog,
        [Parameter(Mandatory = $false)]
        [String]$LogFile,
        [Parameter(Mandatory = $false)]
        [switch]$NoDots,
        [Parameter(Mandatory = $false)]
        [switch]$Silent = $true,
        [Parameter(Mandatory = $false)]
        [switch]$OSVerOverride,
        [Parameter(Mandatory = $false)]
        [switch]$Help


    ) # param

    $startTime = (Get-Date).DateTime

    $Script:RecommendedSWList = @(          # these are checked with '-r' option
        'HP Notifications', `
        'HP Power Manager', `
        'HP Smart Health', `
        'HP Programmable Key', 'HP Programmable Key (SA)', `
        'HP Auto Lock and Awake', `
        'myHP with HP Presence', `
        'System Default Settings' 
    ) # $Script:RecommendedSWList

    if ( $Help ) {
        'Analyzer displays BIOS/Driver/Software updates available for a platform - requires HP CMSL'
        'Runtime options:'
        '.\Analyzer.exe [-ShowHWID] [-noDots] ...'
        '.\Analyzer.exe [-S] [-n] ...'
            '  [-a|-All]                    --- List All Softpaqs and their status'
            '  [-r|-RecommendedSoftware]    --- Add HP software recommendations to analysis:'
            '                               HP Notifications, HP Power Manager, HP Smart Health, HP Programmable Key'
            '                               HP Auto Lock and Awake, myHP with HP Presence, System Default Settings'
            '  [-s|-ShowHWID]               --- display matching PnP hardware ID'
            '  [-l|-LogFile <File>]         --- Log all output to file instead of console'
            '       -l out.txt              log output to out.txt'
            '       -l out.csv              log output to out.csv (formatted) AND to out.txt'
            '  [-c|-CsvLog file[.csv]]      --- log output to out.csv (formatted)'
            '  [-n|-noDots]                 --- avoid displaying dot/Softpaq to console (- )useful when using -l)'
        '  [-x|-XmlFile <File.xml>]]        --- Reference file argument - avoids Internet access for analysis'
        return 0
    } # if ( $Help )

    #####################################################################################
    # Set up initial variables and checks
    #####################################################################################

    if ( $CsvLog -and ([System.IO.Path]::GetExtension($CsvLog) -notlike '.csv') ) {
            $CsvLog = $CsvLog+'.csv'
    }
    # use CMSL to find what is the device
    Try {
        $ThisPlatformID = Get-HPDeviceProductID
        $ThisPlatformName = Get-HPDeviceModel
    } Catch {
        Write-Warning 'HP CMSL is not available on this device, or device not supported'
        return 1
    }
    #####################################################################################
    # if $OS not passed as argument, used installed OS
        $WinOS = Get-CimInstance win32_operatingsystem        # $OS = 'win'+$WinOS.version.split('.')[0]
    if ( $WinOS.BuildNumber -lt 22000 ) { $OS = 'win10' } else { $OS = 'win11' }
    
    #Replaced Dan's Switch Method with grabbing it from the Regsitry
    $OSVer = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'DisplayVersion'

    if ($OSVerOverride){
        $MaxOSSupported = ((Get-HPDeviceDetails -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"} | Select-Object -Unique| measure -Maximum).Maximum
        if ($MaxOSSupported -Match "11"){$MaxOS = "Win11"}
        else {$MaxOS = "Win10"}
        $MaxBuild = ((Get-HPDeviceDetails -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | measure -Maximum).Maximum
        #Write-Host " Max Build Supported for this Device: $MaxBuild"
        #Write-Host " Max OS: $MaxOS"
        $OSVer = $MaxBuild
        $OS = $MaxOS
        $script:OSOVerOverRideComment = "Overriding OS and/or OSVer with: $OS & $OSVer"
        }
    <#  Dan's Method
    switch -Wildcard ( $WinOS.version ) {
        '*18363' { $OSVer = '1909' }
        '*19041' { $OSVer = '2004' }
        '*19042' { $OSVer = '2009' }
        '*19043' { $OSVer = '21H1' }
        '*19044' { $OSVer = '21H2' }
        '*19045' { $OSVer = '22H2' }
        '*22000' { $OSVer = '21H2' }
        '*22621' { $OSVer = '22H2' }
        '*25262' { $OSVer = '22H2' }   # insider preview
        '*25267' { $OSVer = '22H2' }   # insider preview 
        '*25276' { $OSVer = '22H2' }   # insider preview
        '*25290' { $OSVer = '22H2' }   # insider preview 
        default { "OS Version $($OSVer.version) not supported" ; return -1 }
    } # switch -Wildcard ( (Get-WmiObject win32_operatingsystem).version )
    #>
    
    #####################################################################################
    $Script:xmlRefFileContent = $null
    $CacheDir = (Convert-Path (Get-Location))    # get current location of script
    if ( $XmlFile ) {
        if ( Test-Path $XmlFile ) {
            Try {
                $Error.Clear()            
                $SoftpaqList = Get-SoftpaqList -platform $ThisPlatformID -os $OS -OsVer $OSVer -ReferenceUrl $CacheDir -ErrorAction Stop    
            } Catch {
                $error[0].exception          # $error[0].exception.gettype().fullname 
                return 3
            }      
        } else {
            'File not found'
            return 3
        } # else if ( Test-Path $XmlFile )
    
    } else {    
        Try {
            $Error.Clear()   
            $Script:SoftpaqList = Get-SoftpaqList -platform $ThisPlatformID -os $OS -OsVer $OSVer -CacheDir $CacheDir -ErrorAction Stop
        } Catch {
            $error[0].exception                       # $error[0].exception.gettype().fullname 
            'Remove "cache" folder and try again'
            if ( $OSVer -eq '22H2' ) { 'NOTE: CMSL version >= 1.6.8 is required to support Windows 22H2' }
            return -2
        }
        # find the downloaded reference file (as expanded from the cab file)
        $XmlFile = Get-Childitem -Path $CacheDir'\cache' -Include "*.xml" -Recurse -File |
                where { ($_.Directory -match '.dir') -and `
                    ($_.Name -match $ThisPlatformID) -and `
                    ($_.Name -match $OS.Substring(3)) -and `
                    ($_.Name -match $OSVer) }
    } # else if ( $XmlFile )

    $Script:xmlContent = [xml](Get-Content -Path $XmlFile)
    $Script:XMLRefFileDevices = $Script:xmlContent.SelectNodes("ImagePal/Devices/Device")

    # error codes for color coding, etc.
    $TypeError = -1 ; $TypeNorm = 1 ; $TypeWarn = 2 ; $TypeDebug = 4 ; $TypeSuccess = 5 ;$TypeNoNewline = 10

    #####################################################################################
    # End of initialization
    #####################################################################################

    function TraceLog {
	    [CmdletBinding()]
	    param( [Parameter(Mandatory = $false)] $Message, 
            [Parameter(Mandatory = $false)] [int]$Type ) 

	    if ( $null -eq $Type ) { $Type = $TypeNorm }
	    #$LogMessage = "<$Message><time=`"$Time`" date=`"$Date`" type=`"$Type`">"
        if ( $Script:LogFile ) {
            $Message | Out-File -Append -Encoding UTF8 -FilePath $Script:LogFile.replace('.csv','.log')               
        } else {
            if ($Silent -ne $true){
                if ( $Type -eq $TypeNoNewline ) {
                    Write-host $Message -NoNewline
                } else {
                    $Message | Out-Host
                }
            }       
        } # else if ( $Script:LogFile )
    } # function TraceLog

    TraceLog -Message "Analyzer: 2.01.02 -- $($startTime)"
    TraceLog -Message "-- Working Reference File: '$XmlFile'"

    <######################################################################################
        Function Compare_Version
            This function compares 2 driver version strings (4 digits separated by '.')
            Returns 'True' if first parm is higher than second parm 
        parm: $pInstalled       Installed driver version
              $pToMatch         Driver version to compare against (latest)
        return: True (Update needed) if current version is newer than what's installed 
    #>#####################################################################################
    Function Compare_Version {
        [CmdletBinding()] param( $pInstalled, $pToMatch )

        if ( -not $pInstalled ) { return $true }
        # handle case: '1.1.28.1 A 7' (like in HP Notifications)
        if ( $pInstalled.contains(' ') ) { $pInstalled = $pInstalled.split(' ')[0] }  
        if ( $pToMatch.contains(' ') ) { $pToMatch = $pToMatch.split(' ')[0] } 

        $a =$pInstalled.Split(".")
        $b =$pToMatch.Split(".")
        $cv_UpdateNeeded = $false   # assume update is not needed

        if ( [int32]$a[0] -lt [int32]$b[0] ) { $cv_UpdateNeeded = $true 
        } else { 
            if ( [int32]$a[0] -gt [int32]$b[0] ) { $cv_UpdateNeeded = $false 
            } else { # first digits are the same
                if ( [int32]$a[1] -lt [int32]$b[1] ) { $cv_UpdateNeeded = $true 
                } else { 
                    if ( [int32]$a[1] -gt [int32]$b[1] ) { $cv_UpdateNeeded = $false 
                    } else { # second digits are the same
                        if ( [int32]$a[2] -lt [int32]$b[2] ) { $cv_UpdateNeeded = $true 
                        } else { 
                            if ( [int32]$a[2] -gt [int32]$b[2] ) { $cv_UpdateNeeded = $false 
                            } else { # third digits are the same
                                if ( [int32]$a[3] -lt [int32]$b[3] ) { $cv_UpdateNeeded = $true 
                                } else { 
                                    if ( [int32]$a[3] -ge [int32]$b[3] ) { $cv_UpdateNeeded = $false 
                                    } 
                                } # else if ( [int]$a[3] -lt [int]$b[3] ) 
                            }
                        } # else if ( [int]$a[2] -lt [int]$b[2] )
                    }
                } # else if ( [int]$a[1] -lt [int]$b[1] )
            }
        } # else if ( [int]$a[0] -lt [int]$b[0] )

        return $cv_UpdateNeeded
    } # Function Compare_Version

    <######################################################################################
        Function Decode_VersionHexString
            This function returns the int version of the hex string passed as arg
            the argument string may contain other non-hex characters (which are removed)
        parm: $pHexLine      string containing 4 digit hex string separated by '.'
        return: 4 separate int digits (as strings)
    #>#####################################################################################
    Function Decode_VersionHexString {
        [CmdletBinding()] param( $pHexLine )

        $dv_ReturnValue = $null

        if ( $pHexLine.contains('0x') ) {
            foreach ( $i in $pHexLine.split(',') ) {  ## create the driver string
                if ( $i.contains('0x') ) { $dv_ReturnValue += ([int32]$i).Tostring() ; $dv_ReturnValue += '.' }
            } # foreach ( $i in $pHexLine.split(',')
            $dv_ReturnValue = $dv_ReturnValue -replace ".$" # remove last added '.' from string 
        } # if ( $pHexLine.contains('0x') )  

        Return $dv_ReturnValue
    } # Function Decode_VersionHexString

    <######################################################################################
        Function Get_HardwareID
            This function checks for a Softpaq's supported Hardware ID and tries to match
            one in the current system of installed drivers
        parm: $pCVAMetadata         contents of CVA's file
              $pInstalledDrivers    list of installed PnP drivers
        return: matching Hardware ID or $null, and the PnP driver version, PnP driver date
    #>#####################################################################################
    Function Get_HardwareID {
        [CmdletBinding()] param( $pCVAMetadata, $pInstalledDrivers )

        if ( $DebugOutput ) { TraceLog -Message '  > Get_HardwareID() Checking PnP Hardware for match' }

        $gh_MatchedHardwareID = $null
        $gh_PnPDriverVersion = $null
        $gh_PnpDriverDate = $null
        $gh_RefFileVersion = $null
        $gh_DriverProvider = $null
        # CVA file example:
        # [Devices]
        #    HDAUDIO\FUNC_01&VEN_14F1&DEV_50F4="Conexant ISST Audio"
        #    PCI\VEN_8086&DEV_9D70="Intel(R) Smart Sound Technology (Intel(R) SST) Audio Controller"
        #    PCI\VEN_8086&DEV_A170="Intel(R) Smart Sound Technology (Intel(R) SST) Audio Controller"

        # check the list of installed PnP devices for a matching entry in the CVA [Devices] list

        foreach ( $gh_iDriver in $pInstalledDrivers ) {        

            if ( $gh_iDriver.DeviceID ) {  # assume this entry has a h/w ID component (could a s/w entry, print, etc.)
                foreach ($gh_iDevIDEntry in $pCVAMetadata.Devices.Keys) { # $pCVAMetadata.Devices.Keys: entry up to '='

                    if ( $gh_iDevIDEntry -like '_body' ) { continue }

                    # next remove '*' from entry (example: HID\*HPQ6001="HP Wireless Button Driver")
                    #$gh_DevToMatch = ($gh_iDevIDEntry.split('\')[1]).split('=')[0].replace('*','')   # ex. 'VEN_8086&DEV_51FC'
                    $gh_DevToMatch = $gh_iDevIDEntry.split('=')[0]
                    if ( $gh_iDriver.DeviceID -match ($gh_DevToMatch.replace('\','\\')) ) { 
                        $gh_MatchedHardwareID = $gh_DevToMatch
                        $gh_PnPDriverVersion = $gh_iDriver.DriverVersion
                        $gh_PnpDriverDate = $gh_iDriver.DriverDate
                        $gh_DriverProvider = $gh_iDriver.DriverProviderName
                        if ( $gh_PnpDriverDate ) { $gh_PnpDriverDate = $gh_PnpDriverDate.ToString("MM-dd-yyyy") }
                        if ( $DebugOutput ) {
                            TraceLog -Message "  ... Matched CVA Device ID: $($gh_DevToMatch)"
                            TraceLog -Message "  ... Matched HWID : $($gh_MatchedHardwareID)"
                            TraceLog -Message "  ... Matched HWID Driver Version : $($gh_PnPDriverVersion)"
                            TraceLog -Message "  ... Matched HWID Driver Date : $($gh_PnpDriverDate)"
                            TraceLog -Message "  ... Matched HWID Provider Name: $($gh_DriverProvider)"
                        } # if ( $DebugOutput )
                        break
                    } # $gh_iDriver.DeviceID -match $gh_DevToMatch
                    if ( $gh_MatchedHardwareID ) { break }
                } # foreach ($gh_iDevIDEntry in $pCVAMetadata.Devices.Keys)            
            } # if ( $gh_iDriver.DeviceID )

        } # foreach ( $gh_iDriver in $pInstalledDrivers )

        # check 'reference file' for this entry, and get the driver version from it
        if ( $gh_MatchedHardwareID ) {    
            if ( $gh_MatchedHardwareID.contains('&') ) {
                $gh_devEntryToFind = $gh_MatchedHardwareID.split('&')[1]# ACPI\VEN_HPQ&DEV_6007="HP Mobile Data Protection Sensor"
            } else {
                $gh_devEntryToFind = $gh_MatchedHardwareID              # ACPI\HPQ6007="HP Mobile Data Protection Sensor"
            }
            # check the Reference File for devices that match
            foreach ( $gh_iDevEntry in $Script:XMLRefFileDevices.Device ) {
                if ( $gh_iDevEntry.DeviceID -match ($gh_devEntryToFind.replace('\','\\')) ) {  
                    $gh_RefFileVersion = $gh_iDevEntry.DriverVersion    # return the Reference File driver version
                    break
                } # if ( $gh_iDevEntry.DeviceID -match $gh_devEntryToFind
            } # foreach ( $gh_iDevEntry in $Script:XMLRefFileDevices.Device )
        } # if ( $gh_MatchedHardwareID )

        # if the Refernence File <Devices> section does not have this entry,
        # ... check in <Solutions>
        if ( $null -eq $gh_RefFileVersion ) {
            foreach ( $gh_iSolution in $Script:XMLRefFileSolutions.UpdateInfo ) {
                $gh_SolutionID = $gh_iSolution.ID
                $gh_SolutionVersion = $gh_iSolution.Version
                if ( $gh_SolutionID -like $pCVAMetadata.Softpaq.SoftpaqNumber ) {
                    $gh_RefFileVersion = $gh_iSolution.Version
                    break
                }
            } # foreach ( $gh_iSolution in $Script:XMLRefFileSolutions.UpdateInfo )
        } # if ( $null -eq $gh_RefFileVersion )

        if ( $DebugOutput ) {
            if ( $gh_MatchedHardwareID ) {
                TraceLog -Message "  < Get_HardwareID()[0] PnP matched - HWID: $($gh_MatchedHardwareID)"
                TraceLog -Message "  ... [1] HWID Driver version: $($gh_PnPDriverVersion)"
                TraceLog -Message "  ... [2] HWID Driver Date: $($gh_PnpDriverDate)"
                TraceLog -Message "  ... [3] Reference File Version: $($gh_RefFileVersion)"
            } else {
                TraceLog -Message '  < Get_HardwareID() PnP driver NOT matched'
            } # else if ( $gh_MatchedHardwareID )
        } # if ( $DebugOutput )

        return $gh_MatchedHardwareID, $gh_PnPDriverVersion, $gh_PnpDriverDate, $gh_RefFileVersion
    } # Function Get_HardwareID

    <######################################################################################
        Function Get_DriverFileVersion
            This function returns the version string from a CVA file's [DetailFileInformation]
            section from the driver filr, matching the OS version being analyzed or the generic 'WT64'
            Each [DetailFileInformation] entry has the DriverName=... syntax
            ptf.dll=<WINSYSDIR>\DriverStore\FileRepository\dptf_cpu.inf_amd64_897ea327b3fe52f7\,0x0008,0x0007,0x29CC,0x57E6,WT64_2004
        parm: $pCVAContent      contents of CVA's file
              $pOSToMatch       OS to match
              $pOSVerToMatch    OS Version to match
        return: $gd_DetailDriverFileVersion  # driver version from CVA file
                $gd_DriverName           # name of driver from CVA file
    #>#####################################################################################
    Function Get_DriverFileVersion {
        [CmdletBinding()] param( $pCVAMetadata, $pOSToMatch , $pOSVerToMatch )

        if ( $DebugOutput ) { TraceLog -Message '  > Get_DriverFileVersion() Checking Driver File for match' }

        $gd_SoftpaqID = $pCVAMetadata.Softpaq.SoftpaqNumber
        $gd_CVADetailFileInfo = $pCVAMetadata.DetailFileInformation
        $gd_DetailDriverFileVersion = $null
        $gd_CVADetailVersion = $null
        $gd_DriverName = $null   

         # search each key (driver) and see what driver versions it returns, match OS and Version      
        $gd_Drivers = $gd_CVADetailFileInfo.Keys

        foreach ( $gd_iDriver in $gd_Drivers ) {

            if ( $gd_iDriver -like '_body' ) { continue }
            if ( $null -ne $gd_DetailDriverFileVersion ) { break }

            # let's search for driver version in an entry
            foreach ( $gd_iEntry in $gd_CVADetailFileInfo.Item($gd_iDriver) ) {
                # let's match the OS Version 1st
                $gd_iEntryOSVer = $gd_iEntry.Substring($gd_iEntry.Length-4) 

                if ( ($gd_iEntryOSVer -match $pOSVerToMatch) -and ($gd_iEntry -match $pOSToMatch) ) {

                    $gd_CVADetailVersion = Decode_VersionHexString $gd_iEntry -ErrorAction SilentlyContinue
                    $gd_DriverName = $gd_iDriver
                    $gd_DriverPath = $gd_iEntry.split(',')[0]
                    # Exception: make sure the path has a '\' at the end (not always the case)
                    if ( $gd_DriverPath -notmatch '\\$' ) { $gd_DriverPath=$gd_DriverPath+'\' }
                
                    $gd_PathToken = $gd_DriverPath.split('\')[0]  # get CVA coded path token, ex. <WINSYSDIR>, <PROGRAMFILESDIR>, etc.
                
                    switch ( $gd_PathToken ) { # Following from CVA documentation about paths
                        '<DRIVERS>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\Windows\System32\drivers") }
                        '<PROGRAMFILESDIR>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\Program Files") }
                        '<PROGRAMFILESDIRX86>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\Program Files (x86)") }
                        '<WINDIR>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\Windows") }
                        '<WINDISK>' { 
                            $l_SysDrive = (Get-CimInstance -ClassName CIM_OperatingSystem).SystemDrive
                            $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,$l_SysDrive) }
                        '<WINSYSDIR>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\Windows\System32") }
                        '<WINSYSDIRX86>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,"C:\WINDOWS\SYSWOW64") }
                        '<WINSYSDISK>' { $gd_DriverPath=$gd_DriverPath.replace($gd_PathToken,($env:windir).split('\')[0]) }
                        default { '?UNKNOWN?' | out-host }
                    } # switch ( $gd_PathToken )

                    $gd_DriverFullPath = $gd_DriverPath+$gd_DriverName
                    #####################################################################################
                    # check if driver is installed (meaning the file exists) and obtain file version
                    #####################################################################################
                    if ( $DebugOutput ) { TraceLog -Message "    Get_DriverFileVersion(): CVA file Driver Path: $($gd_DriverFullPath)" }
                    if ( Test-Path $gd_DriverFullPath -EA continue ) {
                        $gd_DetailDriverFileVersion = (get-itemproperty $gd_DriverFullPath).versioninfo.FileVersion
                        # Exception: fix returns '8, 5, 3459, 0' instead of '8.5.3459.0' (sp91426 driver dll file)
                        $gd_DetailDriverFileVersion = $gd_DetailDriverFileVersion.replace(', ','.')
                        if ( -not $gd_DetailDriverFileVersion ) {
                            $gd_DetailDriverFileVersion = (get-itemproperty $gd_DriverFullPath).versioninfo.productversion
                        }
                    } else {
                        if ( $DebugOutput ) { TraceLog -Message "    Get_DriverFileVersion(): $($gd_SoftpaqID) -- CVA Driver Path NOT FOUND: $($gd_DriverFullPath)" }
                    }                
                } # if ( ... )

            } # foreach ($v in $f_values)

        } # foreach ($gd_iDriver in $gd_CVADetailFileInfo.Keys)

        if ( $DebugOutput ) {
            TraceLog -Message "  < Get_DriverFileVersion() [0] Driver File Version: $($gd_DetailDriverFileVersion)"
            TraceLog -Message "  < ... [1] Driver File Name: $($gd_DriverName)"
            TraceLog -Message "  < ... [2] Detail File Version: $($gd_CVADetailVersion)"   
        } # if ( $DebugOutput )

        return $gd_DetailDriverFileVersion, $gd_DriverName, $gd_CVADetailVersion
    } # Function Get_DriverFileVersion

    <######################################################################################
        Function Get_InstalledAppx
        Find out if the Softpaq appx has an installed version in system
        parm:   $pAppxFullName      the Appx we are looking for
                $pInstalledAppx     name of appx in system to check for match
        return: $iAppx              the reg entry for the matching appx
    #>#####################################################################################
    Function Get_InstalledAppx {
        [CmdletBinding()] param( $pAppxFullName, $pInstalledAppx ) 

        $gi_AppxInstalledName = $null
        $gi_AppxInstalledVersion = $null

        foreach ( $iAppx in $pInstalledAppx ) {    
            if ( $iAppx.Name -match $pAppxFullName ) {                     
                # get the installed app version from the name string   
                $gi_AppxInstalledName = $iAppx.Name             
                break
            } # if ( $iAppx.Name -match $gu_AppxFullName )
            $iAppx = $null
        } # foreach ( $iAppx in $pInstalledAppx )  

        return $iAppx
    } # Function Get_InstalledAppx

    <######################################################################################
        Function Get_UWPInfo
            This functions determines if the Softpaq has a UWP requirement and if it is installed
        Parms: $pRefFileUWPApps:     content of all UWP apps section from reference file
               $pSoftpaqID:         Softpaq ID
               $pInstalledAppx:     registry list of UWP/appx installed in system
        Returns: the Softpaq UWP name and version, and (if) installed the UWP version
                [0] UWP name - from reference file (or $null)
                [1] UWP version - from reference file (or $null)
                [2] UWP version - from installed UWP (or $null)
                [3] UWP Name - from installed UWP (or $null)
    #>#####################################################################################
    Function Get_UWPInfo {
        [CmdletBinding()] param( $pCVAMetadata, $pInstalledAppx ) 

        $gu_SoftpaqID = $pCVAMetadata.Softpaq.SoftpaqNumber
        if ( $DebugOutput ) { TraceLog -Message "  > Get_UWPInfo(): $($gu_SoftpaqID) - Checking for UWP appx" }
        $gu_CVAUWPName = $null
        $gu_CVAUWPVersion = $null
        $gu_AppxInstalledVersion = $null

        if ( $pCVAMetadata.Private.MS_Store_App -eq 1 ) {
            # find the UWP package info under
            $gu_UWPPackageList = $pCVAMetadata.'Store Package Info'
            foreach ( $iPkg in $gu_UWPPackageList.Keys ) {
                if ($iPkg -notlike '_body' ) {
                    # obtain name of Appx from full name - e.g. 'HPPenSettings' from WacomTechnologyCorp.HPPenSettings_7.7.64.0_neutral__ss941bf8mfs8a
                    # split full appx name into a hash table
                    $gu_UWPPackageHash = $iPkg.split('_')                                  
                    # package: <Name>_<Version>_<Architect>_<ResourceId>_<PublisherId>
                    #           NVIDIAControlPanel_8.1.962.0_x64__56jybvy8sckqj
                    $gu_CVAUWPName = $gu_UWPPackageHash[0]          # NVIDIAControlPanel
                    $gu_CVAUWPVersion = $gu_UWPPackageHash[1]       # 8.1.962.0
                    $gu_AppxArchitecture = $gu_UWPPackageHash[2]    # x64
                    break
                }
            } # foreach ( $iPkg in $gu_UWPPackageList.Keys )

            # now let's see if the Softpaq UWP is an installed appx in the system
            $gu_InstalledAppx =  Get_InstalledAppx $gu_CVAUWPName $pInstalledAppx
            if ( $null -eq $gu_InstalledAppx ) {
                $gu_AppxInstalledVersion = $null
            } else {
                $gu_AppxInstalledVersion = $gu_InstalledAppx.version
            } 
        } # if ( $pCVAMetadata.Private.MS_Store_App -eq 1 )

        if ( $DebugOutput ) {
            if ( $gu_CVAUWPVersion ) {
                TraceLog -Message "  < Get_UWPInfo() Softpaq: $($gu_SoftpaqID)"
                TraceLog -Message "    ... [0] UWP App Name: $($gu_CVAUWPName)" 
                TraceLog -Message "    ... [1] UWP Version: $($gu_CVAUWPVersion)"
                TraceLog -Message "    ... [2] UWP Installed Version: $($gu_AppxInstalledVersion)"                       
            } else {
                TraceLog -Message "  < Get_UWPInfo() Softpaq: $($gu_SoftpaqID) - NO UWP"
            }
        } # if ( $DebugOutput )

        return $gu_CVAUWPName, $gu_CVAUWPVersion, $gu_AppxInstalledVersion
    } # Function Get_UWPInfo

    <######################################################################################
        Function Find_Driver
            This functions attempts to match a Softpaq against an installed driver
            It parses the CVA file [Devices] HW PnP list against this PnP Hardware IDs to find
            a match, and then checks for the associated driver version info against the CVA version
        Parms: $pSoftpaq:       Softpaq node from Get-SoftpaqList
               $pCVAMetadata:   contents of Softpaq's CVA file
               $pInstalledDrivers:  list of installed Drivers in the OS (those w/driver versions)
                    (obtained with 'Get-CimInstance win32_PnpSignedDriver')
        Returns: 5 values
                [0] Matching H/W ID - $null if not found
                [1] Installed driver version (PNP) - $null if not found
                [2] installed driver date
                [3] Reference driver version
                [4] Status
    #>#####################################################################################
    Function Find_Driver {
        [CmdletBinding()] param( $pSoftpaq, $pCVAMetadata, $pInstalledDrivers )

        if ( $DebugOutput ) { TraceLog -Message '  > Find_Driver() Checking driver' }

        $fd_MatchedHardwareID = $null
        $fd_Installed_DriverVersion = $null 

        if ( $Script:OS -eq 'win10') { $Script:OS = 'WT64' }
        if ( $Script:OS -eq 'win11') { $Script:OS = 'W11' }
    
        ##############################################################################
        # get insgtalled driver version matching the CVA driver info in [DetailFileInformation]
        # Get_DriverFileVersion(): $gd_DetailDriverFileVersion, $gd_DriverName, $gd_CVADetailVersion
        $fd_Status = -1
        $fd_CVADriverInfo = Get_DriverFileVersion  $pCVAMetadata $Script:OS $Script:OSVer
        $fd_CVADriverFileVersion = $fd_CVADriverInfo[0]    # this driver is in the system
        $fd_CVADriverFileName = $fd_CVADriverInfo[1]       # driver name
        $fd_CVADriverDetailVersion = $fd_CVADriverInfo[2]  # driver version from CVA [DetailFileInformation]
        if ( $fd_CVADriverFileVersion ) {
            $fd_CVADriverFilecompare = Compare_Version $fd_CVADriverFileVersion $fd_CVADriverDetailVersion
            if ( $fd_CVADriverFilecompare ) { $fd_Status = 1 } else { $fd_Status = 0 }
        }

        ##############################################################################

        ##############################################################################
        # Check installed driver matching the Softpaq's driver hardware ID
        # see if the driver matches an install PnP device
        # Get_HardwareID(): $gh_MatchedHardwareID, $gh_PnPDriverVersion, $gh_PnpDriverDate, $gh_RefFileVersion
        ##############################################################################
        $fd_HardwareCheck = Get_HardwareID $pCVAMetadata $pInstalledDrivers
        $fd_MatchedHardwareID = $fd_HardwareCheck[0]      # [0]=PnP ID matched
        $fd_PnPDriverVersion = $fd_HardwareCheck[1]       # [1]=PnP DriverVersion
        $fd_PnPDriverDate = $fd_HardwareCheck[2]          # [2]=PnP DriverDate
        $fd_RefFileDriverVersion = $fd_HardwareCheck[3]   # [3]=Driver version from Reference file ($null if not in)
        if ( $fd_MatchedHardwareID ) {
            $fd_compareToReferenceFileVersion = Compare_Version $fd_PnPDriverVersion $fd_RefFileDriverVersion    
            if ( $fd_compareToReferenceFileVersion ) { $fd_Status = 1 } else { $fd_Status = 0 }
        }

        if ( $DebugOutput ) {
            TraceLog -Message "  < Find_Driver() [0] SysHardwareID: $($fd_MatchedHardwareID)"
            TraceLog -Message "  < ... [1] Installed DriverVersion: $($fd_PnPDriverVersion)"
            TraceLog -Message "  < ... [2] Installed DriverDate: $($fd_PnPDriverDate)"
            TraceLog -Message "  < ... [3] Ref File DriverVersion: $($fd_RefFileDriverVersion), $($fd_CVADriverDetailVersion)"
            TraceLog -Message "  < ... [4] Status: $($fd_Status)"      
        } # if ( $DebugOutput )
        return $fd_MatchedHardwareID, $fd_PnPDriverVersion, $fd_PnPDriverDate, $fd_RefFileDriverVersion, $fd_Status
    } # Function Find_Driver

    <######################################################################################
        Function Find_Software
            ...
            Parm: $pSoftpaq:        Softpaq node entry to match in device, 
                  $pSpqMetadata:    contents of Softpaq's CVA file
                  $pInstalledSoftware:    List of Uninstall registry app entries
            Return: app found or $null
    #>#####################################################################################
    Function Find_Software {
        [CmdletBinding()] param( $pSoftpaq, $pCVAMetadata, $pInstalledSoftware, $pInstalledWOWApps )

        if ( $DebugOutput ) { TraceLog -Message "   > Find_Software() - Checking Software" }   

        $fs_AppName = $null
        $fs_AppVersion = $null
        $fs_AppDate = $null
        $fs_NameToMatch = $pSoftpaq.name

        # handle exceptions in names between installed app and CVA Title name
        if ( $pSoftpaq.name -match 'BIOS Config Utility' ) { $fs_NameToMatch = 'HP BIOS Configuration Utility' }
        if ( $pSoftpaq.name -match 'Cloud Recovery' ) { $fs_NameToMatch = 'HP Cloud Recovery' }

        # search Uninstall entries for matching Software, list obtained with 'Get-ItemProperty'
        foreach ( $iInst in $pInstalledSoftware ) {
            if ( $iInst.DisplayName -match $fs_NameToMatch ) {
                $fs_AppVersion = $iInst.DisplayVersion
                $fs_AppDate = $iInst.InstallDate
                $fs_AppName = $iInst.DisplayName
                break
            }
        } # foreach ( $iInst in $pInstalledSoftware )

        if ( $null -eq $fs_AppVersion ) {
            # search WoW Uninstall entries for matching Software, list obtained with 'Get-ItemProperty'
            foreach ( $iInst in $pInstalledWOWApps ) {

                if ( $iInst.DisplayName -match $fs_NameToMatch ) {
                    $fs_AppVersion = $iInst.DisplayVersion
                    $fs_AppDate = $iInst.InstallDate
                    $fs_AppName = $iInst.DisplayName
                    break
                }
            } # foreach ( $iInst in $pInstalledSoftware )
        } # if ( $null -eq $fs_AppFound )

        if ( $DebugOutput ) { 
            if ( $fs_AppFound ) {
                TraceLog -Message "  < Find_Software() - Installed Version: $($fs_AppFound.DisplayVersion)"
            } else {
                TraceLog -Message "  < Find_Software() - Software from $($pSoftpaq.id) NOT installed"
            }        
        } # if ( $DebugOutput )
        return $fs_AppVersion, $fs_AppDate, $fs_AppName
    } # Function Find_Software 

    <######################################################################################
        Function Analyze
            Searches the current system for a match for the Softpaq in question
            Parm: $pSoftpaq:        Softpaq node entry (from Get-SoftpaqList) to match in device 
                  $pSpqMetadata:    contents of Softpaq's CVA file
                  $pDriversList:    List of PnP installed drivers, OR
                                    Captured Config Devices list (XML format)
            Return: a PS Hash Table entry containing information about found component
    #>#####################################################################################
    Function Analyze {
        [CmdletBinding()] param( $pSoftpaq, $pSpqMetadata, $pDriversList, $pApps, $pWOWApps, $pInstalledAppxApps, $pRefFileUWPs )

        $SoftpaqHashEntry = @{}

        $a_AnalyzeType = $pDriversList.GetType().BaseType.Name # returns 'Array' or 'XmlNode' (e.g. Target File)
        if ( $DebugOutput ) { TraceLog -Message "  Analyze() $($pSoftpaq.id): $($pSoftpaq.Category)" }

        # setup initial hash entry with certain default data from the Softpaq
        $SoftpaqHashEntry = @{ 
            SoftpaqID = $pSoftpaq.id ; `
            SoftpaqName = $pSoftpaq.name ; `
            SoftpaqVersion = $pSoftpaq.Version ; `
            SoftpaqDate = $pSoftpaq.ReleaseDate ; `
            ReleaseType = $pSoftpaq.ReleaseType ; `
            URL = $pSoftpaq.url ; `
        }
        if ( $pSoftpaq.Category -match 'bios' ) {
            if ( $a_AnalyzeType -eq 'Array') { 
                $a_InstalledBIOS = Get-HPBIOSSettingValue 'System BIOS Version'  # ex. 'Q70 Ver. 01.19.20  03/21/2022'
                $a_InstalledBIOS = $a_InstalledBIOS.split(' ')[2]
                $a_InstalledBIOSDate = $a_InstalledBIOS.substring($a_InstalledBIOS.lastIndexOf(' ')+1)
            } else { #'XMLNode'
                $a_TargetSystem = $pDriversList.SelectNodes("ImagePal/SystemInfo/System")
                $a_InstalledBIOS = $a_TargetSystem.BiosVersion2.split(' ')[2] # BiosVersion2: "Q70 Ver. 01.19.20"
            }
            $a_SoftpaqBIOS = $pSoftpaq.Version
            if ($a_SoftpaqBIOS -match "A"){$a_SoftpaqBIOS = ($a_SoftpaqBIOS.Split("A")[0]).replace(" ","")}
            if ( $a_InstalledBIOS -match "^0" -and ($a_SoftpaqBIOS -notmatch "^0") ) { 
                $a_SoftpaqBIOS =  '0'+$a_SoftpaqBIOS 
            }
            if ( $a_InstalledBIOS -lt $a_SoftpaqBIOS  ) {
                $a_Status = '1'     # "-- BIOS UPDATE AVAILABLE"
            } else {
                $a_Status = '0'     # "-- BIOS UP TO DATE"
            } # else if ( $a_InstalledBIOS -lt $a_SoftpaqBIOS  )
            $SoftpaqHashEntry.Category = 'BIOS' ; `
            $SoftpaqHashEntry.InstallVersion = $a_InstalledBIOS ; `
            $SoftpaqHashEntry.InstallDate = $a_InstalledBIOSDate ; `
            $SoftpaqHashEntry.Status = $a_Status 
            if ( $DebugOutput ) { TraceLog -Message "  Analyze() BIOS Check Status: $($a_Status)" }
        }
        if ( $pSoftpaq.Category -match 'driver' ) {
            #if ( $pSoftpaq.name -match 'firmware' ) { continue }
            if ( $a_AnalyzeType -eq 'Array') { 
                $a_DvrReturnArray = Find_Driver $pSoftpaq $pSpqMetadata $pDriversList
            } else {             #'XMLNode'
                $a_TargetDeviceList = $pDriversList.SelectNodes("ImagePal/Devices/Device")
                $a_DvrReturnArray = Find_Driver $pSoftpaq $pSpqMetadata $a_TargetDeviceList
            }
            # Find_Driver(): $fd_MatchedHardwareID, $fd_PnPDriverVersion, $fd_PnPDriverDate, $fd_RefFileDriverVersion, $fd_Status
            if ( $a_DvrReturnArray[0] ) {      # Hardware ID matched, e.g. not $null
                $SubCategory = $pSoftpaq.Category
                $SubCategoryShort = $SubCategory.Replace(" ","").Split("-") | Select-Object -Last 1
                $SoftpaqHashEntry.SoftpaqVersion = $a_DvrReturnArray[3] ; `
                $SoftpaqHashEntry.Category = 'Driver' ; `
                $SoftpaqHashEntry.Vendor = $pSoftpaq.Vendor ; `
                $SoftpaqHashEntry.SubCategory = $SubCategoryShort ; `
                $SoftpaqHashEntry.InstallVersion = $a_DvrReturnArray[1] ; `
                $SoftpaqHashEntry.InstallDate = $a_DvrReturnArray[2] ; `
                $SoftpaqHashEntry.CVAHWID = $a_DvrReturnArray[0] ; `
                $SoftpaqHashEntry.Status = $a_DvrReturnArray[4] ; `
                $SoftpaqHashEntry.UWP = $pSoftpaq.UWP ; `
                $SoftpaqHashEntry.UWPName = $null ; `
                $SoftpaqHashEntry.UWPVersion = $null ; `
                $SoftpaqHashEntry.UWPInstallVersion = $null ; `
                $SoftpaqHashEntry.CVAStoreApp = $null ; `            # $pSpqMetadata.Private.MS_Store_App    # 0 or 1
                $SoftpaqHashEntry.CVAStorePackageInfo = $null ; `    # is there info in CVA's 'Store Package Info' section?
                $SoftpaqHashEntry.UWPStatus = -1                  # default to 'NOT Installed'           
                if ( $SoftpaqHashEntry.Status -ge 0 ) {      # 0=UP-To-Date, 1=Update, -1=Not Installed
                    if ( $null -eq $SoftpaqHashEntry.InstallVersion ) {
                        # There is a driver available, Hardware exists, but no driver was installed
                        $SoftpaqHashEntry.InstallVersion = 'MISSING'
                    }
                    # check on UWP/appx apps in driver
                    # Get_UWPInfo(): $gu_CVAUWPName, $gu_CVAUWPVersion, $gu_AppxInstalledVersion
                    $a_UWPInfo = Get_UWPInfo $pSpqMetadata $pInstalledAppxApps
                    if ( $a_UWPInfo[1] ) {
                        # we found a Softpaq with a UWP appx listed in the CVA file
                        $SoftpaqHashEntry.UWPName = $a_UWPInfo[0].split('.')[1]
                        $SoftpaqHashEntry.UWPVersion = $a_UWPInfo[1]
                        $SoftpaqHashEntry.UWPInstallVersion = $a_UWPInfo[2]
                        $SoftpaqHashEntry.CVAStorePackageInfo = 1

                        if ( $SoftpaqHashEntry.UWPInstallVersion ) {                            
                            $SoftpaqHashEntry.UWPStatus = 0        # -- UWP UP TO DATE
                            $a_UWPNeesUpdate = Compare_Version $SoftpaqHashEntry.UWPInstallVersion $SoftpaqHashEntry.UWPVersion
                            if ( $a_UWPNeesUpdate) {
                                $SoftpaqHashEntry.UWPStatus = 1    # -- UWP UPDATE AVAILABLE
                            }
                        } else {
                            $SoftpaqHashEntry.UWPStatus = -1       # -- UWP NOT INSTALLED
                        } # else if ( $SoftpaqHashEntry.UWPInstallVersion )
                        if ( $DebugOutput ) {                                
                            TraceLog -Message "  Analyze(): SOFTPAQ NEEDS UPDATE DUE TO UWP: $($SoftpaqHashEntry.UWPName)"
                            TraceLog -Message "  ... UWP Available Version: $($SoftpaqHashEntry.UWPVersion)"
                            TraceLog -Message "  ... UWP Installed Version: $($SoftpaqHashEntry.UWPInstallVersion)"
                            TraceLog -Message "  ... UWP Return code: $($SoftpaqHashEntry.UWPStatus)"
                        } # if ( $DebugOutput )                         
                    } else {
                        if ( $DebugOutput ) { TraceLog -Message "  Analyze() SOFTPAQ DOES NOT INCLUDE UWP" }
                    } # else if ( $a_UWPInfo[1] )
                } # if ( $SoftpaqHashEntry.Status -ge 0 )
            } # if ( $a_DvrReturnArray[0] )
        }
        if ( $pSoftpaq.Category -match 'software' -or `
            ($pSoftpaq.Category -match 'diagnostic') -or `
            ($pSoftpaq.Category -match 'utility') ) {
            $SoftpaqHashEntry.Category = 'Software' ; `
            $SoftpaqHashEntry.InstallVersion = $null ; `
            $SoftpaqHashEntry.InstallDate = $null ; `
            $SoftpaqHashEntry.Status = -1 ; `               # default to "-- SOFTWARE NOT INSTALLED"
            if ( $a_AnalyzeType -eq 'Array') { 
                # $pApps='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
                # $pWOWApps='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                # return $fs_AppVersion, $fs_AppDate, $fs_AppName
                $a_SoftwareFound = Find_Software $pSoftpaq $pSpqMetadata $pApps $pWOWApps
            } else {   # 'XMLNode'
                $f_TargetApps = $pDriversList.SelectNodes("ImagePal/SystemInfo/SoftwareInstalled")
                $a_SoftwareFound = Find_Software $pSoftpaq $pSpqMetadata $f_TargetApps
            }
            if ( $a_SoftwareFound[0] ) { # if version exists ...
                # add found app info to hash table entry
                $SoftpaqHashEntry.InstallVersion = ($a_SoftwareFound[0]).split(' ')[0]
                $SoftpaqHashEntry.InstallDate = $a_SoftwareFound[1]
                if ( $a_AnalyzeType -like 'XMLNode') {      # using a Capture Targe File
                    $SoftpaqHashEntry.InstallVersion = $a_SoftwareFound.Version
                }      
                if ( $SoftpaqHashEntry.InstallVersion ) {
                    # handle Version where there is more than #.#.#.# in string
                    if ( (Compare_Version $SoftpaqHashEntry.InstallVersion $pSoftpaq.Version) ) {
                        $SoftpaqHashEntry.Status = 1        # "-- SOFTWARE UPDATE AVAILABLE"
                    } else {
                        $SoftpaqHashEntry.Status = 0        # "-- SOFTWARE UP TO DATE"
                    }                    
                } # if ( $SoftpaqHashEntry.InstallVersion )
            } else {
                # check if Software installed as UWP package
                # Get_UWPInfo(): $gu_CVAUWPName, $gu_CVAUWPVersion, $gu_AppxInstalledVersion            
                $a_UWPInfo = Get_UWPInfo $pSpqMetadata $pInstalledAppxApps
                $a_UWPInstalledVersion = $a_UWPInfo[2]
                if ( $a_UWPInstalledVersion ) {
                    $SoftpaqHashEntry.InstallVersion = $a_UWPInstalledVersion
                    if ( (Compare_Version $SoftpaqHashEntry.InstallVersion $pSoftpaq.Version) ) {
                        $SoftpaqHashEntry.Status = 1        # "-- SOFTWARE UPDATE AVAILABLE"
                    } else {
                        $SoftpaqHashEntry.Status = 0        # "-- SOFTWARE UP TO DATE"
                    } 
                } else {
                    if ( $Script:RecommendedSoftware -and ( $pSoftpaq.Name -in $Script:RecommendedSWList ) ) {                    
                            $SoftpaqHashEntry.Status = 1    # show as "-- SOFTWARE UPDATE AVAILABLE" 
                                                            # otherwise it won't be listed as Recommended for update
                    } # if ( $Script:RecommendedSoftware )                   
                } # else if ( $a_UWPInstalledVersion )
            } # else if ( $a_SoftwareFound[0] )
        } # if ( $pSoftpaq.Category -match 'software' -or ($pSoftpaq.Category -match 'diagnostic') )

        return $SoftpaqHashEntry
    } # Function Analyze

    <######################################################################################
        Function Get_OutputLine
            Searches the current system for a match for the Softpaq in question
            Parm: $pSoftpaq:        Softpaq node entry (from Get-SoftpaqList) to match in device 
                  $pSpqMetadata:    contents of Softpaq's CVA file
                  $pDriversList:    List of PnP installed drivers, OR
                                    Captured Config Devices list (XML format)
            Return: [0]Console string, [1]CSV string
    #>#####################################################################################
    Function Get_OutputLine {
        [CmdletBinding()] param( $pEntry, $pShowHWID )

        $VerInstallDate = ($pEntry.InstallDate -split ' ')[0]

        #######################################
        # setup the startup output string
        #######################################
    
        $go_msg = "$($pEntry.SoftpaqID),$($pEntry.SoftpaqName),$($pEntry.SoftpaqVersion) $($pEntry.SoftpaqDate)"
        if ( $pEntry.InstallVersion ) {
            if ( $pEntry.InstallVersion -like 'missing' ) {
                $go_msg += ','+$pEntry.InstallVersion+' '+($VerInstallDate)
            } else {
                $go_msg += ',Installed '+$pEntry.InstallVersion+' '+($VerInstallDate)
            }
        } else { 
            $go_msg += ',Not Installed'        
        }
        # add Softpaq category
        $go_msg += ",($($pEntry.Category)-$($pEntry.ReleaseType))"
        # add UWP info
        switch ( $pEntry.UWPStatus ) {                    
            -1  { if ( $pEntry.UWPVersion ) {
                        $go_msg    += ",UWP:$($pEntry.UWPName):$($pEntry.UWPVersion)"
                    } }         
             0  { $go_msg += ",UWP:$($pEntry.UWPName)" } 
             1  { $go_msg += ",UWP Update:$($pEntry.UWPName):$($pEntry.UWPVersion)/[Installed:$($pEntry.UWPInstallVersion)]" } 
        } # switch ( $pEntry.UWPStatus )
        # add HW ID matched to this driver
        if ( $pShowHWID -and $pEntry.CVAHWID ) { $go_msg += ",$($pEntry.CVAHWID)" }        

        #######################################
        # setup the startup output CSV string
        #######################################

        $go_msgCSV = "$($pEntry.SoftpaqID),$($pEntry.SoftpaqName),$($pEntry.SoftpaqVersion)"
        # add the driver date
        if ( $pEntry.InstallVersion ) {        
            $go_msgCSV += ','+$pEntry.InstallVersion
        } else {    
            $go_msgCSV += ','
        }
        # add Softpaq category, release type, and status
        $go_msgCSV += ",($($pEntry.Category)-$($pEntry.ReleaseType)),$($pEntry.Status)"
        # add UWP info matched to this driver
        switch ( $pEntry.UWPStatus ) {                    
            -1  { if ( $pEntry.UWPVersion ) {
                        $go_msgCSV += ",$($pEntry.UWPName),$($pEntry.UWPVersion),,$($pEntry.UWPStatus)"
                    } else {
                        $go_msgCSV += ",,,,"
                    } }         
                0  { $go_msgCSV += ",$($pEntry.UWPName),$($pEntry.UWPVersion),$($pEntry.UWPInstallVersion),$($pEntry.UWPStatus)" }
                1  {  $go_msgCSV += ",$($pEntry.UWPName),$($pEntry.UWPVersion),$($pEntry.UWPInstallVersion),$($pEntry.UWPStatus)" }
            Default { $go_msgCSV += ",,,," }
        } # switch ( $pEntry.UWPStatus )
        # add HW ID matched to this driver
        if ( $pShowHWID -and $pEntry.CVAHWID ) {
            $go_msgCSV += ",$($pEntry.CVAHWID)" 
        } else {
            $go_msgCSV += ","
        } 
        $go_msgCSV += ",$($pEntry.URL)"
        return $go_msg, $go_msgCSV
    } # Function Get_OutputLine()

    # -----------------------------------------------------------------------------------

    #####################################################################################
    # Start of Script
    #####################################################################################

    $CurrLocation = Get-location
    TraceLog -Message "-- Obtaining Softpaq List for platform: [$ThisPlatformID] $ThisPlatformName -- OS: $OS/$OSVer"

    $SoftpaqsUpdateList = @()       # List of Softpaqs that have updates
    $SoftpaqsNOUpdateList = @()     # list of Softpaqs that do NOT require updates
    $SoftpaqsNOTInstalledList = @() # list of Softpaqs that are NOT installed

    TraceLog -Message '-- Retrieving PnP Drivers list for analysis' 
    if ( -not $Script:TargetFile ) {
        $PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver | where { $_.DriverVersion }
    }
    TraceLog -Message '-- Linking to Registry entries (installed apps and UWP)'
    $InstalledApps = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    #$InstalledApps = Get-ItemProperty 'HKLM:\Software\Classes\Installer\Products\*'
    $InstalledWOWApps = Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    #$InstalledAppxApps = Get-ChildItem 'HKLM:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\PackageRepository\Packages'
    $InstalledAppxApps = Get-AppxPackage

    TraceLog -Message '-- Accessing Reference File'
    $Script:XMLRefFileSolutions = $Script:XMlContent.SelectNodes("ImagePal/Solutions")
    $Script:XMLRefFileDevices = $Script:XMlContent.SelectNodes("ImagePal/Devices")
    $XMLRefFileUWPApps = $Script:XMlContent.SelectNodes("ImagePal/SystemInfo/UWPApps")

    TraceLog -Message '-- Analyzing Softpaqs for matches - Please wait...' 
    foreach ( $Spq in $SoftpaqList ) {

        if ( $DebugOutput ) { TraceLog -Message "-- Analyzing Softpaq: $($Spq.id) - $($Spq.name)" }
        if ( -not $Script:LogFile -and (-not $NoDots) ) { TraceLog -Message "." -Type $TypeNoNewline }
     
        Try {
            $Error.Clear()
            $lineNum = ((get-pscallstack)[0].Location -split " line ")[1] # get code line # in case of failure
            $SpqMetadata = Get-SoftpaqMetadata $Spq.id -ErrorAction Stop  # get CVA file for this Softpaq
        } catch {
            $Err = $error[0].exception          # OPTIONAL: $error[0].exception.gettype().fullname 
            if ( $Err -match '404' ) {                
                TraceLog -Message "$($Spq.id): missing CVA file - Get-SoftpaqMetadata exception: on line number $($lineNum)"
            } else {
                if ( $DebugOutput ) { TraceLog -Message "$($Spq.id): Get-SoftpaqMetadata exception: on line number $($lineNum) - $($Err)" }
            }
        } finally {
            # Let's do the analysis
            if ( $TargetFile ) {      # target XML file from runstring
                $SoftpaqEntry = Analyze $Spq $SpqMetadata $xmlTargetContent $InstalledApps $InstalledWOWApps $InstalledAppxApps $XMLRefFileUWPApps
            } else {                  # target is 'this' system
                $SoftpaqEntry = Analyze $Spq $SpqMetadata $PnpSignedDrivers $InstalledApps $InstalledWOWApps $InstalledAppxApps $XMLRefFileUWPApps
            }
            # add Softpaqs to report lists
            switch ( $SoftpaqEntry.Status ) {
            -1  { $SoftpaqsNOTInstalledList += $SoftpaqEntry }  # "-- SOFTPAQ NOT INSTALLED"    {-1}                    
                0  {                                               # "-- SOFTPAQ UP TO DATE"        {0}
                    if ( $SoftpaqEntry.UWPStatus -eq 1 ) {
                        $SoftpaqsUpdateList += $SoftpaqEntry
                    } else {
                        $SoftpaqsNOUpdateList += $SoftpaqEntry
                    } # if ( $SoftpaqEntry.UWPStatus -eq 1 )
                }                
                1  { $SoftpaqsUpdateList += $SoftpaqEntry }        # "-- SOFTPAQ UPDATE AVAILABLE"  {1}                   
            } # switch ( $SoftpaqEntry.Status )
        } # Try catch finally

    } # foreach ( $Spq in $SoftpaqList )

    ####################################################################
    # finally report what we found - Update list first
    # NOTE: Use -l <LogFile> to redirect output
    ####################################################################
    if ( -not $NoDots ) {TraceLog -Message ' '}

    # create CSV output file with column header
    $Headers = "SoftpaqID,SoftpaqName,SoftpaqVersion,InstalledVersion,Category-ReleaseType,Status,UWPName,UWPVersion,UWPInstalledVersion,UWPStatus,HWID,URL"
    if ( $Script:CsvLog ) { $Headers | Out-File $Script:CsvLog -encoding ASCII }

    # 1. report on Driver/BIOS that have updates first (Software next)
    TraceLog -Message '-- Softpaq Updates'
    foreach ( $r in $SoftpaqsUpdateList ) {    
        if ( $r.Category -notmatch 'software' ) {   # Drivers/BIOS first
            $OutString = Get_OutputLine $r $ShowHWID
            TraceLog -Message $OutString[0]
            if ( $Script:CsvLog ) { $OutString[1] | Out-File $Script:CsvLog -encoding ASCII -Append }
        } # if ( $r.Category -notmatch 'software' )
    } # foreach ( $r in $SoftpaqsUpdateList )

    # 2. report on Software that have updates, includes 'HP Recommended' (with -r option)
    #TraceLog -Message '' ; TraceLog -Message '-- Softpaq Updates - Software'
    foreach ( $r in $SoftpaqsUpdateList ) { 
        if ( $r.Category -match 'software' ) {      # output Software last
            $OutString = Get_OutputLine $r $ShowHWID # $OutString[0]= msg, $OutString[1]= CSV msg string    
            TraceLog -Message $OutString[0] 
            if ( $Script:CsvLog ) { $OutString[1] | Out-File $Script:CsvLog -encoding ASCII -Append }
        } # if ( $r.Category -match 'software' )
    } # foreach ( $r in $SoftpaqsUpdateList )

    ####################################################################
    # NEXT: Softpaqs that do not need updating, unless not wanted
    ####################################################################

    if ( $All ) {
        # 3. report on Driver/BIOS that have updates first (Software next)
        if ( $SoftpaqsNOUpdateList.count -gt 0 ) {
            TraceLog -Message '' ; TraceLog -Message '-- Softpaqs Up to Date'
        }
        foreach ( $r in $SoftpaqsNOUpdateList ) { 
            if ( $r.Category -notmatch 'software' ) {
                $OutString = Get_OutputLine $r $ShowHWID # $OutString[0]= msg, $OutString[1]= CSV msg string  
                TraceLog -Message $OutString[0] 
                if ( $Script:CsvLog ) { $OutString[1] | Out-File $Script:LogFile -encoding ASCII -Append }
            }
        } # foreach ( $r in $SoftpaqsNOUpdateList )

        # 4. report on Software that have NO updates
        foreach ( $r in $SoftpaqsNOUpdateList ) { 
            if ( $r.Category -match 'software' ) { # output Software last
                $OutString = Get_OutputLine $r $ShowHWID # $OutString[0]= msg, $OutString[1]= CSV msg string 
                TraceLog -Message $OutString[0] 
                if ( $Script:CsvLog ) { $OutString[1] | Out-File $Script:CsvLog -encoding ASCII -Append }    
            }
        } # foreach ( $r in $SoftpaqsNOUpdateList )

        # 5. report on Softpaqs not installed last
        if ( $SoftpaqsNOTInstalledList.count -gt 0 ) {   #'' ; '-- Softpaqs NOT Installed'
            TraceLog -Message '' ; TraceLog -Message '-- Softpaq Updates - Software NOT Installed'   
            foreach ( $r in $SoftpaqsNOTInstalledList ) { 
                if ( $r.Category -match 'software' ) {
                    $OutString = Get_OutputLine $r $ShowHWID # $OutString[0]= msg, $OutString[1]= CSV msg string 
                    TraceLog -Message $OutString[0] 
                    if ( $Script:Output2CSV ) { $OutString[1] | Out-File $Script:CsvLog -encoding ASCII -Append }      
                } # if ( $r.Category -notmatch 'software' )
            } # foreach ( $r in $SoftpaqsNOTInstalledList )
        }
    } # if ( -not $UpdatesOnly )

    if ( $Script:CsvLog ) { 
        '' | Out-File $Script:CsvLog -encoding ASCII -Append   # add empty line
        ',,,,,1=Update Available; 0=Up To Date; -1=NOT Installed' | Out-File $Script:CsvLog -encoding ASCII -Append
    }
    $endTime = get-date
    $elapsedTime = New-TimeSpan -Start $startTime -End $EndTime
    TraceLog -Message "-- Analyzer done in (min:sec) ($($elapsedTime.ToString("mm\:ss")))" #$elapsedTime.ToString("dd\.hh\:mm\:ss")

    Set-location $CurrLocation

    return $SoftpaqsUpdateList
}

Function Invoke-HPDriverUpdate {
        <#
    .Name
        HPDriverUpdate.ps1

    .Synopsis
        Leverages Analyzer to install HP Softpaqs needed on a device by Category

    .DESCRIPTION
        Finds Driver Softpaqs that can update the current system, then updates them

    .Notes  
        Author: Gary Blok/HP Inc
        23.11.09 - initial release
        23.11.10 - added override parameter (-OSVerOverride), which allows you to run in unsupported land
           - This is useful when you're running an unsupported OS on a device.  This typically happens when you run a new OS on older hardware.

    .Dependencies
        Requires HP Client Management Script Library
        HP Business class devices (as supported by HPIA and HP CMSL)
        Internet access. Analyzer downloads content from Internet


    .Parameters
        -DriverType   -- [String] Driver Type Categories that you want to install.  Default = ALL
        -details      -- [switch] include HP Software HP recommends


    .Examples
        # check for current driver updates available and trigger the installs
        Invoke-HPDriverUpdate

        # check for current driver updates and trigger updates for network devices
        Invoke-HPDriverUpdate -DriverType Network

        # check for current driver updates and trigger updates for network devices while adding verbose to the install commandline
        Invoke-HPDriverUpdate -DriverType Network -details
    #>
    
    [CmdletBinding()]
    param(
    #    [Parameter(Mandatory = $false)]
    #    [String]$DriverType,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("All","Audio", "Graphics", "Chipset", "FirmwareandDriver", "Network", "Keyboard", "MouseandInputDevices")]
        [string]$DriverType = "All",
        [switch]$Test,
        [switch]$OSVerOverride,
        [switch]$Details #Enables Verbose on the Softpaq Install Command


    ) # param
    if ($OSVerOverride){
        $UpdatesAvailable = Invoke-HPAnalyzer -OSVerOverride
    }
    else {
        $UpdatesAvailable = Invoke-HPAnalyzer
    }
    
    if (!($UpdatesAvailable.Category -match "Driver")){
        $UpdatesForDriverType = $null
    }

    $OSCurrent = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $OSVer = $OSCurrent.GetValue('DisplayVersion')
    $UBR = "$($OSCurrent.GetValue('CurrentBuild')).$($OSCurrent.GetValue('UBR'))"
    $WinOS = Get-CimInstance win32_operatingsystem        # $OS = 'win'+$WinOS.version.split('.')[0]
    if ( $WinOS.BuildNumber -lt 22000 ) { $OS = 'Win10' } else { $OS = 'Win11' }


    $Model = $((Get-CimInstance -ClassName Win32_ComputerSystem).Model)
    $Platform = $((Get-CimInstance -ClassName win32_baseboard).Product)
    Write-Output "---------------------------------------------------------------"
    Write-Host "Device Info: Platform $Platform  | Model $Model" -ForegroundColor Green
    Write-Host "OS: $OS | OSVer: $OSVer | UBR: $UBR " -ForegroundColor green
    if ($OSVerOverride){
    Write-Host "Running in OSVerOverride Mode - this is not supported by HP as these updates are not tested with this combination of hardware and OS" -ForegroundColor Red
    Write-Host "$script:OSOVerOverRideComment (the latest supported OS for this platform)" -ForegroundColor Red

    }

    if ($DriverType -eq "All"){
        $UpdatesForDriverType = $UpdatesAvailable | Where-Object {$_.Category -notmatch "BIOS"}
    }
    else {
        $UpdatesForDriverType = $UpdatesAvailable | Where-Object {$_.SubCategory -match $DriverType}
    }

    if (!($UpdatesAvailable.Category -match "Driver")){
        $UpdatesForDriverType = $null
    }

    if ($UpdatesForDriverType.Count -gt 0){
        if (!(Test-Path -Path "C:\SWSetup")){
            new-item -Path "C:\SWSetup" -ItemType Directory -Force | Out-Null
        }
        #Remove Deplicate Vendor Graphic Updates (Drop oldest Softpaq Date)
        $GraphicUpdates = $UpdatesForDriverType | Where-Object {$_.SubCategory -match "Graphics"}
        if ($GraphicUpdates.count -gt 1){
            ForEach ($Vendor in ($GraphicUpdates.Vendor | Select-Object -Unique)){
                #Write-Host $Vendor
                $VendorGraphicUpdates = $GraphicUpdates | Where-Object {$_.Vendor -match $Vendor}
                if ($VendorGraphicUpdates.count -gt 1){
                    $MinDate = ($VendorGraphicUpdates.SoftpaqDate | Select-Object -Unique| measure -Minimum).Minimum
                    $DumpDriver = $VendorGraphicUpdates | Where-Object {$_.SoftpaqDate -eq $MinDate}
                    $UpdatesForDriverType = $UpdatesForDriverType | Where-Object {$_.SoftpaqID -ne $DumpDriver.SoftpaqID}
                }
            }
        }


        foreach ($Update in $UpdatesForDriverType){

            Write-Output "--------------------------------------------------"
            Write-Host "Found Updated Driver $($Update.SoftpaqName)" -ForegroundColor Cyan
            Write-Output " Release Date:       $($Update.SoftpaqDate)"
            Write-Output " Updated Version:    $($Update.SoftpaqVersion)"
            Write-Output " Installed Verson:   $($Update.InstallVersion)"
            Write-Output " SoftPaqID:          $($Update.SoftpaqID)"
            #Start Update Process
            Write-Output " Starting Update...."
            
            if ($Details){
                Write-Output "  Get-Softpaq -Number $($Update.SoftpaqID) -Action silentinstall -DestinationPath C:\SWSetup -SaveAs C:\SWSetup\$($Update.SoftpaqID).exe -Verbose"
                if ($Test){
                    Write-Output " !!! Skipping Install Command - Test Mode !!!"
                }
                else {
                    Get-Softpaq -Number $Update.SoftpaqID -Action silentinstall -quiet -DestinationPath "C:\SWSetup" -SaveAs "C:\SWSetup\$($Update.SoftpaqID).exe" -Verbose
                }
            }
            else {
                Write-Output "  Get-Softpaq -Number $($Update.SoftpaqID) -Action silentinstall -DestinationPath C:\SWSetup -SaveAs C:\SWSetup\$($Update.SoftpaqID).exe"
                if ($Test){
                    Write-Output " !!! Skipping Install Command - Test Mode !!!"
                }
                else {
                    Get-Softpaq -Number $Update.SoftpaqID -Action silentinstall -quiet -DestinationPath "C:\SWSetup" -SaveAs "C:\SWSetup\$($Update.SoftpaqID).exe"
                }
            }
            Write-Output " Completed Install of Softpaq"
        }
    }
    else {
        Write-Output "No Updates found for DriverType: $DriverType"
    }
    if (!($UpdatesAvailable.Category -match "Driver")){
        $UpdatesAvailable
        if ($UpdatesAvailable -match "Cannot validate argument on parameter 'OsVer'"){
            Write-Host "Try again with -OSVerOverride parameter to bypass supported OS check" -ForegroundColor Red
        }
    }
}

#Invoke-HPDriverUpdate -DriverType Network

#Get-Softpaq -Number sp142308 -Action silentinstall -Quiet -DestinationPath "C:\SWSetup" -SaveAs "C:\SWSetup\sp142308.exe" -Verbose#+

 #$Update = Get-Softpaq -Number sp101129 -Action silentinstall -quiet -DestinationPath "C:\SWSetup" -SaveAs "C:\SWSetup\sp101129.exe" -Verbose


# $UpdatesForDriverType = $UpdatesAvailable | Where-Object {$_.SubCategory -match "Graphics"}
