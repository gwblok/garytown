function Test-HPIASupport ([string]$PlatformID){

    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    if (!(Test-Path $CabPath)){
        Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    }
    if (!(Test-Path $XMLPath)){
        $Expand = expand $CabPath $XMLPath
    }
    [xml]$XML = Get-Content $XMLPath
    $Platforms = $XML.ImagePal.Platform.SystemID
    if ($PlatformID){
        $MachinePlatform = $PlatformID
        }
    else {
        $MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
    if ($MachinePlatform -in $Platforms){$HPIASupport = $true}
    else {$HPIASupport = $false}

    return $HPIASupport
    }

function Get-HPOSSupport {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$Latest,
    [switch]$MaxOS,
    [switch]$MaxOSVer,
    [switch]$MaxOSNum
    )
    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $XMLPlatforms = $XML.ImagePal.Platform
    $OSList = ($XMLPlatforms | Where-Object {$_.SystemID -match $MachinePlatform}).OS | Select-Object -Property OSReleaseIdDisplay, OSBuildId, OSDescription
    
    if ($Latest){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        [String]$MaxOSVerion = (($OSList | Where-Object {$_.OSDescription -eq "$MaxOSSupported"}).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
        return "$MaxOSSupported $MaxOSVerion"
        break
    }
    if ($MaxOS){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        if ($MaxOSSupported -Match "11"){[String]$MaxOSName = "Win11"}
        else {[String]$MaxOSName = "Win10"}
        return "$MaxOSName"
        break
    }
    if ($MaxOSVer){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        [String]$MaxOSVersion = (($OSList | Where-Object {$_.OSDescription -eq "$MaxOSSupported"}).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
        return "$MaxOSVersion"
        break
    }
    if ($MaxOSNum){
        [String]$MaxOSSupported = ($OSList.OSDescription | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
        if ($MaxOSSupported -Match "11"){[String]$MaxOSNumber = "11.0"}
        else {[String]$MaxOSNumber = "10.0"}
        return "$MaxOSNumber"
        break
    }
    return $OSList
}

function Get-HPSoftpaqListLatest {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$SystemInfo,
    [switch]$MaxOSVer,
    [switch]$MaxOSNum
    )
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"){
        $Arch = '64'
    }

    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $OSNum = Get-HPOSSupport -MaxOSNum -Platform $MachinePlatform
    $ReleaseID = Get-HPOSSupport -MaxOSVer -Platform $MachinePlatform
    $BaseURL = ("https://hpia.hpcloud.hp.com/ref/$($MachinePlatform)/$($MachinePlatform)_$($Arch)_$($OSNum).$($ReleaseID).cab").ToLower()
    #https://hpia.hpcloud.hp.com/ref/83b2/83b2_64_11.0.23h2.cab
    $CabPath = "$env:TEMP\HPIA.cab"
    $XMLPath = "$env:TEMP\HPIA.xml"
    Write-Verbose "Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing"
    Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing -ErrorAction SilentlyContinue
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $SoftpaqList = $XML.ImagePal.Solutions.UpdateInfo
    if ($SystemInfo){
        $SysInfo = $XML.ImagePal.SystemInfo.System
        return $SystemInfo
        break
    }
    return $SoftpaqList

}

function Get-HPSoftPaqItems {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string] $Platform,
    [Parameter(Position=1,mandatory=$true)]
    [string] $osver,
    [Parameter(Position=2,mandatory=$true)]
    [ValidateSet("10.0","11.0")]
    [string] $os
    )

    
    
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"){$Arch = '64'}
    $CabPath = "$env:TEMP\HPIA.cab"
    $XMLPath = "$env:TEMP\HPIA.xml"
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    
    #Test Passed Parameters
    $OSList = Get-HPOSSupport -Platform $MachinePlatform
    if ($OS -eq "11.0"){
        $OK = $OSList | Where-Object {$_.OSDescription -match "Windows 11"}
        if ($null -eq $OK){
        Write-Error "Your option of OS: $OS is not valid, This platform does not support Windows 11"
        break
        }
    }
    if ($OS -eq "10.0"){
        $OK = $OSList | Where-Object {$_.OSDescription -match "Windows 10"}
        if ($null -eq $OK){
        Write-Error "Your option of OS: $OS is not valid, This platform does not support Windows 10"
        break
        }
    }
    $SupportedOSVers = $OSList.OSReleaseIdDisplay
    if ($osver -notin $SupportedOSVers){
        Write-Host -ForegroundColor red "Selected Release $OSVer is not supported by this Platform: $MachinePlatform"
        Write-Error " Use Get-HPOSSupport to find list of options"
        break
    }
    $BaseURL = ("https://hpia.hpcloud.hp.com/ref/$($MachinePlatform)/$($MachinePlatform)_$($Arch)_$($os).$($osver).cab").ToLower()
    Write-Verbose "Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing"
    Invoke-WebRequest -Uri $BaseURL -OutFile $CabPath -UseBasicParsing
    $Expand = expand $CabPath $XMLPath
    [xml]$XML = Get-Content $XMLPath
    $SoftpaqList = $XML.ImagePal.Solutions.UpdateInfo

    return $SoftpaqList

}

function Get-HPDriverPackLatest {
    [CmdletBinding()]
    param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$Platform,
    [switch]$URL,
    [switch]$download
    )
    if ($Platform){$MachinePlatform = $platform}
    else {$MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product}
    $OSList = Get-HPOSSupport -Platform $MachinePlatform
    if (($OSList.OSDescription) -contains "Microsoft Windows 11"){
        $OS = "11.0"
        #Get the supported Builds for Windows 11 so we can loop through them
        $SupportedWinXXBuilds = ($OSList| Where-Object {$_.OSDescription -match "11"}).OSReleaseIdDisplay | Sort-Object -Descending
        if ($SupportedWinXXBuilds){
            write-Verbose "Checking for Win $OS Driver Pack"
            [int]$Loop_Index = 0
            do {
                Write-Verbose "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
                $DriverPack = Get-HPSoftPaqItems -osver $($SupportedWinXXBuilds[$loop_index]) -os $OS -Platform $MachinePlatform -ErrorAction SilentlyContinue | Where-Object {$_.Category -match "Driver Pack"}
                #$DriverPack = Get-SoftpaqList -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win11" -ErrorAction SilentlyContinue
            
                if (!($DriverPack)){$Loop_Index++;}
                if ($DriverPack){
                    Write-Verbose "Windows 11 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
                }
            }
            while ($null -eq $DriverPack -and $loop_index -lt $SupportedWinXXBuilds.Count)
        }
    }

    if (!($DriverPack)){ #If no Win11 Driver Pack found, check for Win10 Driver Pack
        if (($OSList.OSDescription) -contains "Microsoft Windows 10"){
            $OS = "10.0"
            #Get the supported Builds for Windows 10 so we can loop through them
            $SupportedWinXXBuilds = ($OSList| Where-Object {$_.OSDescription -match "10"}).OSReleaseIdDisplay | Sort-Object -Descending
            if ($SupportedWinXXBuilds){
                write-Verbose "Checking for Win $OS Driver Pack"
                [int]$Loop_Index = 0
                do {
                    Write-Verbose "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
                    $DriverPack = Get-HPSoftPaqItems -osver $($SupportedWinXXBuilds[$loop_index]) -os $OS -Platform $MachinePlatform -ErrorAction SilentlyContinue | Where-Object {$_.Category -match "Driver Pack"}
                    #$DriverPack = Get-SoftpaqList -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win10" -ErrorAction SilentlyContinue
                    if (!($DriverPack)){$Loop_Index++;}
                    if ($DriverPack){
                        Write-Verbose "Windows 10 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
                    }
                }
                while ($null-eq $DriverPack  -and $loop_index -lt $SupportedWinXXBuilds.Count)
            }
        }
    }
    if ($DriverPack){
        Write-Verbose "Driver Pack Found: $($DriverPack.Name) for Platform: $Platform"
        if($PSBoundParameters.ContainsKey('Download')){
            Save-WebFile -SourceUrl "https://$($DriverPack.URL)" -DestinationName "$($DriverPack.id).exe" -DestinationDirectory "C:\Drivers"
        }
        else{
        if($PSBoundParameters.ContainsKey('URL')){
                return "https://$($DriverPack.URL)"
            }
            else {
                return $DriverPack
            }
        }
    }
    else {
        Write-Verbose "No Driver Pack Found for Platform: $Platform"
        return $false
    }
}

function Invoke-HPIAOfflineSync {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("All", "BIOS", "Driver", "Software", "Firmware", "UWPPack")]
        $Category = "Driver",
        [Parameter(Mandatory=$false)]
        $OS = "win11",
        [Parameter(Mandatory=$false)]
        $Release = "23H2"
    )
    
    #Create HPIA Repo & Sync for this Platform (EXE / Online)
    $LogFolder = "C:\OSDCloud\Logs"
    $HPIARepoFolder = "C:\OSDCloud\HPIA\Repo"
    $PlatformCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $HPIARepoFolder -ItemType Directory -Force | Out-Null
    $CurrentLocation = Get-Location
    Set-Location -Path $HPIARepoFolder
    Initialize-Repository | out-null
    Set-RepositoryConfiguration -Setting OfflineCacheMode -CacheValue Enable | out-null
    Add-RepositoryFilter -Os $OS -OsVer $Release -Category $Category -Platform $PlatformCode | out-null
    Write-Host "Starting HPCMSL to create HPIA Repo for $($PlatformCode) with Drivers" -ForegroundColor Green
    write-host " This process can take several minutes to download all drivers" -ForegroundColor Gray
    write-host " Writing Progress Log to $LogFolder" -ForegroundColor Gray
    write-host " Downloading to $HPIARepoFolder" -ForegroundColor Gray
    Invoke-RepositorySync -Verbose 4> "$LogFolder\HPIAOfflineSync.log"
    Set-Location $CurrentLocation
    Write-Host "Completed Driver Download for HP Device to be applied in OOBE" -ForegroundColor Green
}