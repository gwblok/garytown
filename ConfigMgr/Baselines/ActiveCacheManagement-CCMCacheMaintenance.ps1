<#
Gary Blok | @gwblok | RecastSoftware.com
Credit Keith Garner for most of the code

.SYNOPSIS
SCCM Cache Cleaner script

.DESCRIPTION
Basic management of local Nomad Cache

Remove All packages that are missing local references
Remove All packages that are no longer being managed by CCM ( Unreferenced ) 
Remove All Software Updates, older than 90 days, on Large Disks
Remove All non-persistent packages, older than 30 days, on small disks
Delete software updates one by one down to 30 days or CCMCache size drops below threshold
Non-persistent items one by one down to 30 days or CCMCache size drops below threshold


.NOTES
For support questions, mailto:G=EUC-CCMPE@wellsfargo.com

When running with a Configuration Item:

    [switch]$CIRemediate  # will run Detection
    [switch]$CIRemediate = $True  # will run Remediation

#>


$OrgName = "Recast_IT"
[string]$Version = '2021.04.22'
$RegConfig = "HKLM:\Software\$OrgName\Cache"
$LogName = "CCMCacheChecker.log"
$LogDir = "$env:ProgramData\$OrgName\Logs"
$LogFile = "$LogDir\$LogName"
$ComponentText = "CCMCacheCheck"
$CIStatus = @()
$Module = 'CCMCacheCleaner'
$SizeRequested = 25GB
$SmallDisk = 100GB


$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CCMCacheLocation = $CMCacheObjects.Location

#################

#region Library 1 IMPORTED FROM: [.\Common.Library.ps1]
########################################
# Library 1 IMPORTED FROM: [.\Common.Library.ps1]
# Common Library

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

function Set-AppSettingIncrement {
    [cmdletbinding()]
    param (
        [string] $Name
    )

    [int]$Value = Get-AppSettings @PSBoundParameters
    Set-AppSettings @PSBoundParameters -Value ($Value + 1).ToString()
}

function Get-AppSettings {
    [cmdletbinding()]
    param ( [string] $Name )

    if ( -not $RegConfig ) { throw "missing $RegConfig" }
    if ( -not ( test-path $RegConfig ) ) {
        new-item -ItemType Directory -Path $RegConfig -force -ErrorAction SilentlyContinue | Out-Null
    }
    try { Get-ItemPropertyValue -Path $RegConfig -name $Name | Write-Output } catch {}
}

function Set-AppSettings {
    [cmdletbinding()]
    param ( [string] $Name, $Value )
    if ( $Value -and ( $Value.GetType().Name -in 'Int32','Int64','uint32','uint64','double' ) -and ($Value -gt 3MB ) ) {
        CMTraceLog -Message  ("`t`tSettings: [$Name] = [$value]  {0:N0} MB" -f ( $value / 1MB )) -Type 1 -LogFile $LogFile
    }
    else {
        CMTraceLog -Message  "`t`tSettings: [$Name] = [$value]" -Type 1 -LogFile $LogFile
    }
    if ( -not $RegConfig ) { throw "missing $RegConfig" }
    if ( -not ( test-path $RegConfig ) ) {
        new-item -ItemType Directory -Path $RegConfig -force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -path $RegConfig -name $Name -Value $Value | Out-Null
}

Function Exit-WithError {
    [cmdletbinding()]
    param ( 
        [int] $ExitCode,
        [string] $module = 'CacheUtility',
        [string] $Msg
    )

    if ( $ExitCode -ne 0 ) { 
        CMTraceLog -Message  "ERROR: $Msg" -Type 1 -LogFile $LogFile
        New-EventLog -LogName Application -Source $module -ErrorAction SilentlyContinue
        Write-EventLog -LogName Application -Source $module -EventId $ExitCode -Message $msg
    }
    else {
        CMTraceLog -Message  "$Msg" -Type 1 -LogFile $LogFile
    }

    Set-AppSettings -name 'LastStatusInt' -Value $ExitCode
    Set-AppSettings -name 'LastStatusMsg' -Value $Msg

    exit $ExitCode
}

function Approve-ObjectIfRemediate {
    [cmdletbinding()]
    param ( 
        [parameter(ValueFromPipeline=$true)]  $InputObject,
        [string] $PropertyName
        )

    process {
        if ( -not $CIRemediate ) {
            if ( $PropertyName ) {
                $Name = $InputObject | % $PropertyName
            }
            else {
                $Name = $InputObject
            }
            CMTraceLog -Message  "Do not remediate object, flag for use later" -Type 1 -LogFile $LogFile
            $Text = $Name | out-string
            CMTraceLog -Message  $Text -Type 1 -LogFile $LogFile
            $global:isComplaint = $Name
        }
        else {
            $InputObject | Write-Output
        }
    }
}

Function Get-VolumeEx {
<#
Windows 7 does not have Get-Volume
#>
    [cmdletbinding()]
    param ( $DriveLetter = 'c' )
    
    gwmi win32_logicaldisk -Filter "DeviceID='$($DriveLetter.Substring(0,1))`:'" |
        Select -Property Size,FileSystem,
        @{Name='SizeRemaining';Expression={$_.FreeSPace}},
        @{Name='DriveLetter';Expression={$_.Caption.SubString(0,1)}},
        @{Name='FileSystemLabel';Expression={$_.VolumeName}}
}

function Invoke-As64Bit {
    <#
    Re-Invoke Powershell, this time as a 64-bit process.
    Warning, will only return 1 or 0 as last error code.
    Example usage:
        if ( Invoke-As64Bit -Invokation $myInvocation -arks $args ) {
            write-host "finished $lastexitcode"
            exit $lastexitcode
        }
    #>
    [cmdletbinding()]
    param( [parameter(Mandatory=$true)] $Invokation, $arks )

    #Re-Invoke 
    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        if ($Invokation.Line) {
            write-verbose "RUn Line: $($Invokation.Line)"
            & "$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -noninteractive -NoProfile $Invokation.Line
        }else{
            write-verbose "RUn Name: $($Invokation.InvocationName) $arks"
            & "$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -noninteractive -NoProfile -file "$($Invokation.InvocationName)" $arks
        }
        return $true
    }
    return $false
}
#endregion



$script:CCM = $null

function Get-CCMCachePath {
    Get-CCMCacheSettings location | Write-Output
}

function Get-CCMCacheSettings {
    [cmdletbinding()]
    param ( [string] $Name )

    Test-ForCCM
    $script:CCM.GetCacheInfo().$Name | Write-Output
}

function Set-CCMCacheSettings {
    [cmdletbinding()]
    param ( [string] $Name, [string] $Value )
    CMTraceLog -Message  "`t`tSettings: [$Name] = [$value]" -Type 1 -LogFile $LogFile
    Test-ForCCM
    $script:CCM.GetCacheInfo().$Name = $Value
}

function Test-ForCCM {
    try {
        if ( -not $script:CCM ) {
            $script:CCM = new-object -ComObject UIResource.UIResourceMgr -ErrorAction SilentlyContinue
        }
    } catch {}

    if ( -not $script:CCM ) { Exit-WithError 101 'Missing CCM Installation - Service' }
}

function Get-CCMPackages {
    Test-ForCCM
    $script:ccm.GetCacheInfo().GetCacheElements() | write-output
}

function Test-ForPersist {
    param ( 
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]        
        $Keys
    )
    begin {
        $PersistList = Get-WmiObject -Namespace root\ccm\SoftMgmtAgent -class CacheInfoEx |
        Where-Object {  ( $_.DeploymentFlags -band 33554432 ) -eq 33554432 } |
        foreach-object { $_.cacheid }
    }
    process {
        $Keys | Where-Object { $_.CacheElementID.trim('{}') -in $PersistList } | Write-Output
    }

}

function Test-ForNotPersist {
    param ( 
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]        
        $Keys
    )
    begin {
        $PersistList = Get-WmiObject -Namespace root\ccm\SoftMgmtAgent -class CacheInfoEx |
        Where-Object {  ( $_.DeploymentFlags -band 33554432 ) -eq 33554432 } |
        foreach-object { $_.cacheid }
    }
    process {
        $Keys | Where-Object { $_.CacheElementID.trim('{}') -notin $PersistList } | Write-Output
    }

}

function Remove-CCMPackage {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ( 
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]        
        $Keys
    )
    process {
        foreach ( $Key in $Keys ) {
            CMTraceLog -Message  "`t`tRemove $($Key.CacheElementID) / $($Key.ContentID) Age: $($key.LastReferenceTime) Size: $($Key.ContentSize / 1KB -as [int]) MB" -Type 1 -LogFile $LogFile
            if (-not $CIRemediate) { 
                $script:CIStatus += "NotCompliant: $($Key.CacheElementID) Age: $($key.LastReferenceTime)  Size: $($Key.ContentSize / 1KB) MB`r`n"
            }
            elseif ( $Pscmdlet.ShouldPRocess("$key.CacheElementID","Remove") ) {

                CMTraceLog -Message  "Actually Removing $KEY.CacheElementID" -Type 1 -LogFile $LogFile
                Test-ForCCM
                $script:ccm.GetCacheInfo().DeleteCacheElement($Key.CacheElementID)

            }
        }
    }

}

Function Test-ForCCMSoftwareUpdate {
    # Content in a {GUID} folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.ContentID | Select-String -Pattern '^[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$' } | write-output }
}

Function Test-ForCCMLegacyContent {
    # Content in a CAS00001 folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.ContentID | Select-String -Pattern '^[\dA-Z]{3}[\dA-F]{5}$' } | write-output }
}

Function Test-ForCCMApplicationDeployment {
    # Content in a Content_{GUID} folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.ContentID | Select-String -Pattern '^Content_[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$' } | write-output }
}


#region Main()
#############################################################

$DiskSize = Get-VolumeEx c | foreach-object { $_.Size }
$FreeSize = Get-VolumeEx c | foreach-object { $_.SizeRemaining }

#######################################

if ( -not ( Get-AppSettings -Name 'Exempt' | Where-Object { $_ -eq 'True' } ) ) {

    Test-ForCCM
    $CCMTotalSize = Get-CCMCacheSettings TotalSize
    CMTraceLog -Message  "CCM Total Size: $CCMTotalSize" -Type 1 -LogFile $LogFile

    #######################################

    #Rule: Remove All non-persistent packages, older than 30 days, on small disks
    if ( $DiskSize -lt $SmallDisk ) {
        Get-CCMPackages | ? { $_.LastReferenceTime.adddays(30) -lt [datetime]::now} | 
            Test-ForNotPersist | 
            Remove-CCMPackage
    }

    #######################################

    #Rule: Remove All Software Updates, older than 90 days, on Large Disks
    if ( $DiskSize -gt $SmallDisk ) {
        Get-CCMPackages | ? { $_.LastReferenceTime.adddays(90) -lt [datetime]::now} | 
            Test-ForCCMSoftwareUpdate | 
            Remove-CCMPackage
    }

    #######################################

    #Rule: Remove All packages that are no longer being managed by CCM ( Unreferenced ) 

    $Exclude = @{}
    Get-CCMPackages | foreach-object  { $Exclude.add($_.Location,$_) }
    Get-CCMCachePath | get-childitem | Where-object { -not ($exclude.contains( $_.FullName ) ) } | 
        ForEach-Object {
        CMTraceLog -Message  "Remove CACHE Item: $($_.FUllName)" -Type 1 -LogFile $LogFile
        Remove-Item -Force -Recurse $_.FUllName
        }

    #######################################

    #Rule: Remove All packages that are missing local references

    Get-CCMPackages | where-object { -not ( test-path $_.location ) } | 
        Remove-CCMPackage

    #######################################

    $CCMCacheSize = get-childitem $CCMCacheLocation -recurse -exclude skpswi.dat | measure-object -sum length | foreach-object { $_.Sum }

    $Count = 1
    while ( 

        # Rule: CCMCache greater than 10GB (on small disks), 10% (on disks 100 - 500), 50 GB (on disks greater than 500 GB)
        ( ( $DiskSize -gt 500GB ) -and ( $CCMCacheSize -gt 50gb ) ) -or 
        ( ( $DiskSize -lt 100GB ) -and ( $CCMCacheSize -gt 10gb ) ) -or 
        (                              ( $CCMCacheSize -gt ( $DiskSize * 0.1 ) ) ) -or 

        # Rule: Free disk space is less than 10% (on disks less than 250 GB) or less than 25 GB (on disks greater than 250 GB)
        ( ( $DiskSize -gt 250GB ) -and ( $FreeSize -lt 25gb ) ) -or 
        ( ( $DiskSize -lt 250GB ) -and ( $FreeSize -lt ( $DiskSize * 0.1 ) ) ) -or 

        ( $false )
        )
    {
        CMTraceLog -Message  "Remediate $CCMCacheSize too big or Free SIze $FreeSize too small on $DiskSize  ..." -Type 1 -LogFile $LogFile

        # SubRule: Delete software updates one by one down to 30 days or CCMCache size drops below threshold
        $Found = Get-CCMPackages | 
            ? { $_.LastReferenceTime.adddays(30) -lt [datetime]::now} | 
            Test-ForCCMSoftwareUpdate | 
            sort LastReferenceTime | 
            Select-Object -first 1

        if ( -not $found ) { 

            # SubRule: Non-persistent items one by one down to 30 days or CCMCache size drops below threshold
            $Found = Get-CCMPackages | 
                ? { $_.LastReferenceTime.adddays(30) -lt [datetime]::now} | 
                Test-ForNotPersist  | 
                sort LastReferenceTime | 
                Select-Object -first 1

        }

        if ( -not $found ) {
            $CIStatus += "Too much Cache $($CCMCacheSize/1GB) GB, nothing to remove!"
            CMTraceLog -Message  "WARNING: No packages found to remove." -Type 1 -LogFile $LogFile
            break
        }
        $Found | Remove-CCMPackage

        ##############

        if ( -not $CIRemediate ) {break}

        $FreeSize = Get-VolumeEx c | foreach-object { $_.SizeRemaining }
        $CCMCacheSize = get-childitem c:\windows\ccmcache -recurse -exclude skpswi.dat | measure-object -sum length | foreach-object { $_.Sum }
        CMTraceLog -Message  "CacheSize: $($CCMCacheSize/1GB) GB  FreeSize: $($FreeSIze/1GB) GB"-Type 1 -LogFile $LogFile

        if ( $Count -gt 200 ) 
            { 
            CMTraceLog -Message  "BAIL" -Type 1 -LogFile $LogFile
            break 
            }
        $count += 1

    }

    CMTraceLog -Message  "Finished: $Count" -Type 1 -LogFile $LogFile

    #######################################

    write-verbose "Write Summary to Registry"

    Set-AppSettings -Name 'CCMTotalSize' -Value $CCMTotalSize
    Set-AppSettings -Name 'CCMCacheSize'  -Value (get-childitem c:\windows\ccmcache -recurse -exclude skpswi.dat | measure-object -sum length | foreach-object { $_.Sum })
    Set-AppSettings -Name 'CCMCacheItems' -Value (get-childitem c:\windows\ccmcache | Where-Object {  $_.PSISContainer } | measure-object | foreach-object { $_.Count })

}


#######################################

write-verbose "Write Summary to Registry"

Set-AppSettings -Name 'DiskSize' -Value $DiskSize
Set-AppSettings -Name 'FreeSize' -Value $FreeSize
Set-AppSettings -Name 'Version' -value $Version.ToString()
if ( -not $CIStatus ) { $CIStatus = 'Compliant' } else { $CiStatus = 'noncompliant' }
Write-host $CIStatus
Set-AppSettings -Name 'LastStatusInt' -Value 0
Set-AppSettings -Name 'LastStatusMsg' -Value $CIStatus

#endregion
